# dbtui.nvim

A Neovim plugin to open [dbtui](https://github.com/Di3go0-0/dbtui) in a floating terminal window, similar to how lazygit.nvim wraps lazygit.

dbtui is a terminal database client (Oracle, PostgreSQL, MySQL) with vim-like navigation, oil-style floating navigator, tab groups, and SQL query execution.

## Requirements

- Neovim >= 0.8
- [dbtui](https://github.com/Di3go0-0/dbtui) binary in your `PATH`

Install dbtui via [crates.io](https://crates.io/crates/dbtui):

```sh
cargo install dbtui
```

Or build from source:

```sh
git clone https://github.com/Di3go0-0/dbtui.git
cd dbtui
cargo install --path .
```

## Installation

### [folke/lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "Di3go0-0/dbtui.nvim",
    dependencies = {},
    config = function()
        require("dbtui").setup()
    end,
    keys = {
        { "<leader>db", "<cmd>Dbtui<cr>", desc = "Toggle dbtui" },
    },
}
```

### [wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "Di3go0-0/dbtui.nvim",
    config = function()
        require("dbtui").setup()
    end,
}
```

### [junegunn/vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'Di3go0-0/dbtui.nvim'

" In your init.vim, after plug#end():
lua require("dbtui").setup()
```

## Configuration

```lua
require("dbtui").setup({
    -- Path to dbtui binary (default: "dbtui")
    dbtui_cmd = "dbtui",

    -- Floating window options
    float_opts = {
        width = 0.9,    -- 90% of editor width
        height = 0.9,   -- 90% of editor height
        border = "rounded",
    },

    -- Auto-open dbtui when entering .sql files (once per buffer)
    open_on_sql_file = false,

    -- Keymap (normal mode in nvim) to toggle dbtui. Set to nil to disable.
    keymap = "<leader>db",

    -- Keymap (terminal mode, while focused on the dbtui window) to hide it
    -- without killing the process. Use a key dbtui itself does not bind.
    -- Set to nil to disable.
    hide_keymap = "<C-q>",

    -- Check for updates (compares installed vs crates.io)
    check_updates = true,

    -- Also check on plugin setup (nvim startup), not just on first toggle.
    -- Deferred and async — no startup penalty.
    check_updates_on_startup = true,

    -- Extra arguments to pass to the dbtui CLI
    extra_args = {},
})
```

## Usage

| Command   | Description           |
|-----------|-----------------------|
| `:Dbtui`  | Toggle dbtui window   |

Default keymap: `<leader>db`

### Hide vs quit (background instance)

Pressing the toggle keymap on a visible dbtui window **hides** the floating window without killing dbtui. The terminal buffer keeps running in the background, so when you toggle it back open you get exactly where you left off — same open tabs, queries, cursor position, scroll, connections, everything.

dbtui only fully exits when you quit it from inside the app (`<leader>q q`). After that, the next toggle spawns a fresh instance.

This means you can keep dbtui "loaded" across your whole nvim session and pop it open whenever you need it without losing context.

#### Hiding from inside dbtui

Because dbtui captures all keys while focused (including its own `<leader>` chords), the nvim-side `<leader>db` won't reach nvim when you're inside the floating terminal. To hide without leaving terminal mode, the plugin sets a buffer-local terminal-mode keymap on the dbtui window:

| Key                   | Action                                       |
|-----------------------|----------------------------------------------|
| `<C-q>` (default)     | Hide the dbtui window (process keeps running)|

You can rebind it via `hide_keymap` in `setup()`, or set it to `nil` to disable. Pick any key dbtui itself doesn't bind — `<C-q>`, `<F12>`, `<M-d>`, etc. all work. After hiding, reopen with `<leader>db` from anywhere in nvim.

### Update notifications

The plugin compares your installed dbtui version against the latest on crates.io and pops a `vim.notify` when an update is available. By default the check runs once on nvim startup (deferred 1s, fully async — no startup penalty) and once on first toggle per session.

- `check_updates = false` disables the check entirely.
- `check_updates_on_startup = false` keeps the check on first toggle but skips the startup one.

When an update is available you'll see something like:

```
dbtui update available: 0.2.3 → 0.2.4
Run: cargo install dbtui
```

### Auto-open on `.sql` files

Set `open_on_sql_file = true` to launch dbtui automatically the first time you enter a `.sql` buffer in a session.

### Mouse handling

Mouse events inside the floating terminal are blocked so terminal scrollback can't corrupt the TUI rendering. All navigation happens through the keyboard (vim-style hjkl, leader keys, etc.).

## Inside dbtui

Once dbtui is open, see the in-app help with `?` or `<leader>?`. Quick reference:

| Key                | Action                                      |
|--------------------|---------------------------------------------|
| `<leader>e`        | Toggle sidebar                              |
| `<leader>E`        | Toggle floating navigator (oil-style)       |
| `<leader>\|`        | Vertical split (tab group)                  |
| `<leader>m`        | Move tab to other group                     |
| `<leader>b d`      | Close tab                                   |
| `<leader>w d`      | Close tab group                             |
| `<leader>q q`      | Quit dbtui                                  |
| `<leader>f e/i`    | Export / import connections                 |
| `<leader>Enter`    | Execute query at cursor                     |
| `Tab` / `S-Tab`    | Cycle tabs in focused group                 |
| `]` / `[`          | Cycle sub-views (Data / Properties / DDL)   |
| `Ctrl+]` / `Ctrl+[`| Next / previous diagnostic                  |

## License

MIT
