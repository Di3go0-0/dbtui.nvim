local M = {}
local config = require("dbtui.config")

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
local update_checked = false
local function check_for_updates()
    if update_checked then return end
    update_checked = true

    if not config.options.check_updates then return end

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

function M.toggle()
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
        win = nil
        return
    end

    if not check_binary() then return end
    check_for_updates()

    local opts = config.options.float_opts
    local width = math.floor(vim.o.columns * opts.width)
    local height = math.floor(vim.o.lines * opts.height)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    buf = vim.api.nvim_create_buf(false, true)
    win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = opts.border,
        style = "minimal",
    })

    -- Build command
    local cmd = config.options.dbtui_cmd

    -- Extra user-defined arguments
    for _, arg in ipairs(config.options.extra_args) do
        cmd = cmd .. " " .. arg
    end

    vim.fn.termopen(cmd, {
        on_exit = function()
            if win and vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
                win = nil
            end
        end,
    })

    -- Block mouse events to prevent terminal scrollback from corrupting the TUI
    local nop = { noremap = true, silent = true }
    vim.api.nvim_buf_set_keymap(buf, "t", "<ScrollWheelUp>", "<Nop>", nop)
    vim.api.nvim_buf_set_keymap(buf, "t", "<ScrollWheelDown>", "<Nop>", nop)
    vim.api.nvim_buf_set_keymap(buf, "t", "<LeftMouse>", "<Nop>", nop)
    vim.api.nvim_buf_set_keymap(buf, "t", "<2-LeftMouse>", "<Nop>", nop)
    vim.api.nvim_buf_set_keymap(buf, "t", "<RightMouse>", "<Nop>", nop)
    vim.api.nvim_buf_set_keymap(buf, "t", "<MiddleMouse>", "<Nop>", nop)
    vim.api.nvim_buf_set_keymap(buf, "t", "<LeftDrag>", "<Nop>", nop)
    vim.api.nvim_buf_set_keymap(buf, "t", "<LeftRelease>", "<Nop>", nop)

    vim.cmd("startinsert")
end

return M
