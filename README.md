# resurrect.nvim

very simple buffer tracker.

something like [tpope/vim-obsession](https://github.com/tpope/vim-obsession) is probably better for a "real" session management

## Config

```lua
{
    'taybart/resurrect.nvim',
    opts = {
        status_icon = '🪦', -- for use in status line with `g:has_resurrect_sessions`
        add_command = true, -- add Resurrect user command
        always_choose = true, -- show picker even if one session exists
        quiet = false, -- print message to console when sessions are found
        preview_depth = 4, -- how many folders will be shown in the preview
    },
}
```

## Usage

You can start a new session with `:Resurrect start {session_name}`, if `session_name` is left out, `default` will be used.

After reopening nvim, you can run `:Resurrect` to choose a session to resurrect.

If you would like to stop tracking a session run `:Resurrect stop`, and if you would like to remove a session run `:Resurrect delete {session_name}`, if `session_name` is left out you will be able to choose a session to delete.

## Status line

In order to see that you have available resurrect sessions you can add the status icon to your status line. This will be either `opts.status_icon` by itself or will be `opts.status_icon {session_name}` when a session is active.

For example with `nvim-lualine/lualine.nvim`:

```lua
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        sections = {
          lualine_a = {},
          lualine_c = {
            { 'filename', file_status = true, path = 1 },
          },
          lualine_x = { 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'g:has_resurrect_sessions' },
        },
      })
    end,
  },
```
