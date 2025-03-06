return {
  "williamboman/mason.nvim",
  opts = {
    ensure_installed = {
      "stylua",
      "shellcheck",
      "shfmt",
      "flake8",
      "luacheck",
      "css-lsp",
      "typescript-language-server",
      "tailwindcss-language-server",
    },
  },
}
