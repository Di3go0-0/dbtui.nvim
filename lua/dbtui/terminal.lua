local M = {}
local config = require("dbtui.config")

-- buf is kept alive across hide/show so the dbtui process keeps running
-- in the background. Only cleared when dbtui actually exits.
local buf, win

--- Check if the dbtui binary is available in PATH.
local function check_binary()
    local cmd = config.options.dbtui_cmd
    if vim.fn.executable(cmd) == 0 then
        vim.notify(
            "dbtui not found in PATH. Install with: cargo install dbtui",
            vim.log.levels.ERROR,
            { title = "dbtui.nvim" }
        )
        return false
    end
    return true
end

--- Check for updates asynchronously (compares installed vs latest on crates.io).
--- Runs at most once per nvim session. Safe to call from setup() — fully async.
local update_checked = false
function M.check_for_updates()
    if update_checked then return end
    update_checked = true

    if not config.options.check_updates then return end
    if vim.fn.executable(config.options.dbtui_cmd) == 0 then return end

    local cmd = config.options.dbtui_cmd
    -- Get installed version
    vim.fn.jobstart(cmd .. " --version", {
        stdout_buffered = true,
        on_stdout = function(_, data)
            local installed = nil
            for _, line in ipairs(data) do
                local ver = line:match("(%d+%.%d+%.%d+)")
                if ver then
                    installed = ver
                    break
                end
            end
            if not installed then return end

            -- Check latest version on crates.io
            vim.fn.jobstart("curl -sf https://crates.io/api/v1/crates/dbtui", {
                stdout_buffered = true,
                on_stdout = function(_, crate_data)
                    local json_str = table.concat(crate_data, "")
                    if json_str == "" then return end
                    local ok, parsed = pcall(vim.json.decode, json_str)
                    if not ok or not parsed then return end
                    local latest = parsed.crate and parsed.crate.max_version
                    if not latest then return end

                    if latest ~= installed then
                        vim.schedule(function()
                            vim.notify(
                                "dbtui update available: "
                                    .. installed
                                    .. " → "
                                    .. latest
                                    .. "\nRun: cargo install dbtui",
                                vim.log.levels.INFO,
                                { title = "dbtui.nvim" }
                            )
                        end)
                    end
                end,
            })
        end,
    })
end

--- Open a centered floating window pointing at the given buffer.
local function open_float(target_buf)
    local opts = config.options.float_opts
    local width = math.floor(vim.o.columns * opts.width)
    local height = math.floor(vim.o.lines * opts.height)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    return vim.api.nvim_open_win(target_buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = opts.border,
        style = "minimal",
    })
end

--- Block mouse events on the buffer so terminal scrollback can't corrupt the TUI.
local function block_mouse(target_buf)
    local nop = { noremap = true, silent = true }
    local maps = {
        "<ScrollWheelUp>",
        "<ScrollWheelDown>",
        "<LeftMouse>",
        "<2-LeftMouse>",
        "<RightMouse>",
        "<MiddleMouse>",
        "<LeftDrag>",
        "<LeftRelease>",
    }
    for _, m in ipairs(maps) do
        vim.api.nvim_buf_set_keymap(target_buf, "t", m, "<Nop>", nop)
    end
end

--- Force the dbtui process to redraw at the current window dimensions.
---
--- When we reattach an existing terminal buffer to a new floating window,
--- nvim doesn't always call uv_pty_resize because the window dimensions
--- match what the pty already has. The TUI keeps drawing at the old size
--- — content drifts left, columns get cut off.
---
--- The fix is two-pronged:
---  1. Open the window 1 column smaller than target, then resize it back
---     up. This guarantees nvim sees an actual size change and calls
---     uv_pty_resize, which kicks SIGWINCH into the child pty.
---  2. Send SIGWINCH directly to the child pid via vim.uv.kill as a
---     belt-and-suspenders backup so dbtui re-queries terminal dims even
---     if the pty resize was a no-op.
local function force_redraw(target_buf, target_win)
    if not (target_win and vim.api.nvim_win_is_valid(target_win)) then return end

    -- Step 1: shrink-then-restore to force uv_pty_resize.
    local cfg = vim.api.nvim_win_get_config(target_win)
    local shrunk = vim.tbl_extend("force", {}, cfg, { width = math.max((cfg.width or 1) - 1, 1) })
    pcall(vim.api.nvim_win_set_config, target_win, shrunk)
    vim.schedule(function()
        if target_win and vim.api.nvim_win_is_valid(target_win) then
            pcall(vim.api.nvim_win_set_config, target_win, cfg)
        end
    end)

    -- Step 2: SIGWINCH the child process directly.
    vim.schedule(function()
        local ok, job_id = pcall(vim.api.nvim_buf_get_var, target_buf, "terminal_job_id")
        if not ok or not job_id then return end
        local pid = vim.fn.jobpid(job_id)
        if not pid or pid <= 0 then return end
        if vim.uv and vim.uv.kill then
            pcall(vim.uv.kill, pid, "sigwinch")
        else
            pcall(vim.fn.jobstart, { "kill", "-WINCH", tostring(pid) }, { detach = true })
        end
    end)
end

--- Bind the configured hide keymap inside the terminal so the user can hide
--- dbtui without leaving terminal mode (and without it interfering with
--- dbtui's internal leader bindings).
local function bind_hide_key(target_buf)
    local key = config.options.hide_keymap
    if not key or key == "" then return end
    vim.api.nvim_buf_set_keymap(
        target_buf,
        "t",
        key,
        [[<C-\><C-n><Cmd>lua require('dbtui.terminal').hide()<CR>]],
        { noremap = true, silent = true, desc = "Hide dbtui (keep process alive)" }
    )
end

--- Open (or focus) dbtui without hiding it.
---
--- - Window already visible: focuses it.
--- - Buffer alive but window hidden: reattaches a window so the user gets
---   back exactly where they left off (tabs, queries, cursor, connections).
--- - No instance yet (or previous one exited): spawns a fresh dbtui.
function M.open()
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        vim.cmd("startinsert")
        return
    end

    if buf and vim.api.nvim_buf_is_valid(buf) then
        win = open_float(buf)
        force_redraw(buf, win)
        vim.cmd("startinsert")
        return
    end

    if not check_binary() then return end
    M.check_for_updates()

    buf = vim.api.nvim_create_buf(false, true)
    win = open_float(buf)

    -- Build the command as a list so nvim execs it directly without a shell
    -- wrapper. That way jobpid() returns dbtui's pid, not the shell's, so
    -- SIGWINCH actually reaches the right process on reattach.
    local cmd_list = { config.options.dbtui_cmd }
    for _, arg in ipairs(config.options.extra_args) do
        table.insert(cmd_list, arg)
    end

    vim.fn.termopen(cmd_list, {
        on_exit = function()
            -- dbtui actually exited — close the window AND wipe the buffer
            -- so the next open spawns a fresh instance.
            if win and vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
            if buf and vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
            win = nil
            buf = nil
        end,
    })

    block_mouse(buf)
    bind_hide_key(buf)
    vim.cmd("startinsert")

    -- The first frame dbtui draws often uses stale pty dimensions because
    -- nvim sets up the pty before the floating window has fully settled.
    -- Trigger the same shrink-restore + SIGWINCH dance we use on reattach
    -- so dbtui re-queries terminal size on its first proper draw cycle.
    -- Deferred so dbtui has time to start its event loop before SIGWINCH.
    vim.defer_fn(function()
        force_redraw(buf, win)
    end, 80)
end

--- Hide the dbtui window without killing the process. No-op if no window.
function M.hide()
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_hide(win)
        win = nil
    end
end

--- Toggle dbtui: hide if visible, otherwise open (reattaching state if any).
function M.toggle()
    if win and vim.api.nvim_win_is_valid(win) then
        M.hide()
    else
        M.open()
    end
end

return M
