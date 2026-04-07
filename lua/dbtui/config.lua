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

    -- Keymap (terminal mode, while focused on the dbtui window) to hide it
    -- without killing the process. Default is <C-Space>: pinky on Ctrl,
    -- thumb on Space — fast and reachable. dbtui doesn't bind it, the tty
    -- doesn't eat it, and it doesn't collide with common Zellij bindings
    -- (avoid <C-q>/<C-s> which are XON/XOFF, and <M-q> which Zellij uses).
    -- Set to nil to disable.
    hide_keymap = "<C-Space>",

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
