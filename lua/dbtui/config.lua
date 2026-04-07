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

    -- Keymap to toggle dbtui (set to nil to disable)
    keymap = "<leader>db",

    -- Check for updates on first toggle (compares installed vs crates.io)
    check_updates = true,

    -- Extra arguments to pass to the dbtui CLI
    extra_args = {},
}

M.options = {}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
