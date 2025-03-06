return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "debugloop/telescope-undo.nvim",
  },
  config = function()
    require("telescope").setup({
      pickers = {
        find_files = {
          find_command = { "rg", "--files", "--iglob", "!.git", "--hidden" },
        },
        grep_string = {
          additional_args = { "--hidden" },
        },
        live_grep = {
          additional_args = { "--hidden" },
        },
      },
      keys = {},
      -- change some options
      opts = {
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { prompt_position = "top" },
          sorting_strategy = "ascending",
          winblend = 0,
        },
      },

      extensions = {
        undo = {
          -- telescope-undo.nvim config, see below
        },
        -- other extensions:
        -- file_browser = { ... }
      },
    })
    require("telescope").load_extension("undo")
    vim.keymap.set("n", "<leader>ut", "<cmd>Telescope undo<cr>")
  end,
}
