return {
  {
    "folke/persistence.nvim",
    enabled = false,
  },
  {
    "tpope/vim-obsession",
    lazy = false,
    cond = function()
      return vim.env.TMUX ~= nil and vim.env.TMUX ~= ""
    end,
    keys = {
      { "<leader>qO", "<cmd>Obsess<cr>", desc = "Start Session Capture" },
      { "<leader>qD", "<cmd>Obsess!<cr>", desc = "Stop Session Capture" },
    },
    config = function()
      local cwd = vim.fn.getcwd()

      if vim.fn.isdirectory(cwd) == 0 or vim.fn.filewritable(cwd) ~= 2 then
        return
      end

      local session = vim.fs.joinpath(cwd, "Session.vim")
      vim.schedule(function()
        vim.cmd("silent! Obsess " .. vim.fn.fnameescape(session))
      end)
    end,
  },
}
