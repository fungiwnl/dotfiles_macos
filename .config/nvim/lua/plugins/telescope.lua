return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "debugloop/telescope-undo.nvim",
  },
  config = function()
    local rg_ignore_file = vim.fn.stdpath("config") .. "/.telescope_ignore"
    local find_files_command = {
      "rg",
      "--files",
      "--hidden",
      "--no-ignore-vcs",
      "--ignore-file",
      rg_ignore_file,
    }

    require("telescope").setup({
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--hidden",
          "--no-ignore-vcs",
          "--ignore-file",
          rg_ignore_file,
        },
        file_ignore_patterns = {
          "%.git/",
          "node_modules/",
        },
      },
      pickers = {
        find_files = {
          find_command = find_files_command,
        },
      },
      extensions = {
        undo = {},
      },
    })
    require("telescope").load_extension("undo")
    vim.keymap.set("n", "<leader>ut", "<cmd>Telescope undo<cr>")
    vim.keymap.set("n", "<leader><space>", function()
      require("telescope.builtin").find_files({
        cwd = require("lazyvim.util").root(),
        find_command = find_files_command,
      })
    end, { desc = "Find Files (Root Dir)" })
  end,
}
