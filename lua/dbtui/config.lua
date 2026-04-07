local M = {}

M.defaults = {
    -- Path to dbtui binary
    dbtui_cmd = "dbtui",

    -- Floating window options
    float_opts = {
        width = 0.9,
        height = 0.9,
        border = "rounded",
    },

    -- Auto-open dbtui when entering .sql files (once per buffer)
    open_on_sql_file = false,

    -- Keymap (normal mode in nvim) to toggle dbtui. Set to nil to disable.
    keymap = "<leader>db",

    -- Keymap (normal mode in nvim) to open dbtui without toggling — focuses
    -- if visible, reattaches if hidden, spawns if no instance. Set to nil
    -- to disable. nil by default; users can opt in.
    open_keymap = nil,

    -- Keymap (terminal mode, while focused on the dbtui window) to hide it
    -- without killing the process. NOTE: dbtui uses <C-h> internally for
    -- spatial navigation between panels and tab groups. Binding it here
    -- means dbtui will never receive Ctrl+h — use h/l in normal mode for
    -- navigation instead. Avoid <C-q>/<C-s> (XON/XOFF) and <M-q> (Zellij).
    -- Set to nil to disable.
    hide_keymap = "<C-h>",

    -- Check for updates on first toggle (compares installed vs crates.io)
    check_updates = true,

    -- Check for updates on plugin setup (nvim startup) too, so you get notified
    -- without having to open dbtui first. Async, no startup penalty.
    check_updates_on_startup = true,

    -- Extra arguments to pass to the dbtui CLI
    extra_args = {},
}

M.options = {}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
