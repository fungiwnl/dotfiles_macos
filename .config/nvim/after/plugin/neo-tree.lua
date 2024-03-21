require'neo-tree'.setup({
  close_if_last_window = true,
  filesystem = {
    filtered_items = {
        visible = true, -- when true, they will just be displayed differently than normal items
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_by_name = { 
          "node_modules"
        }
    }
  },
  follow_current_file = {
    enabled = true, -- This will find and focus the file in the active buffer every time
    --               -- the current file is changed while the tree is open.
    leave_dirs_open = true, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
  },
  group_empty_dirs = false, -- when true, empty folders will be grouped together
  hijack_netrw_behavior = "open_default", -- netrw disabled, opening a directory opens neo-tree
                                          -- in whatever position is specified in window.position
                      -- "open_current",  -- netrw disabled, opening a directory opens within the
                      -- -- window like netrw would, regardless of window.position
                      -- "disabled",    -- netrw left alone, neo-tree does not handle opening dirs
  use_libuv_file_watcher = true, -- This will use the OS level file watchers to detect changes
                                  -- instead of relying on nvim autocmd events 
  buffers = {
    follow_current_file = {
        enabled = true, -- This will find and focus the file in the active buffer every time
        --              -- the current file is changed while the tree is open.
        leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
    }
  }
})
