local M = {}

function M.setup(opts)
    require("dbtui.config").setup(opts)
    local config = require("dbtui.config").options

    -- Check for updates on startup so the user is notified about new releases
    -- without having to open dbtui first. Deferred so it never blocks startup.
    if config.check_updates and config.check_updates_on_startup then
        vim.defer_fn(function()
            require("dbtui.terminal").check_for_updates()
        end, 1000)
    end

    vim.api.nvim_create_user_command("Dbtui", function()
        require("dbtui.terminal").toggle()
    end, { desc = "Toggle dbtui database client" })

    if config.keymap then
        vim.keymap.set("n", config.keymap, function()
            require("dbtui.terminal").toggle()
        end, { desc = "Toggle dbtui database client" })
    end

    -- Auto-open on .sql files (only once per buffer)
    if config.open_on_sql_file then
        local opened = {}
        vim.api.nvim_create_autocmd("BufEnter", {
            pattern = { "*.sql" },
            callback = function(ev)
                if not opened[ev.buf] then
                    opened[ev.buf] = true
                    require("dbtui.terminal").toggle()
                end
            end,
        })
    end
end

return M
