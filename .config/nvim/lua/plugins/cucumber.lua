-- lua/plugins/cucumber.lua
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        cucumber_language_server = {
          cmd = { "cucumber-language-server", "--stdio" },
          filetypes = { "cucumber" },
          root_dir = function(arg1, on_dir)
            local util = require("lspconfig.util")
            local fname = type(arg1) == "number" and vim.api.nvim_buf_get_name(arg1) or arg1
            local root = util.root_pattern(
              "cucumber.json",
              "cucumber.js",
              "cucumber.cjs",
              "cucumber.mjs",
              "package.json",
              "tsconfig.json",
              "pnpm-workspace.yaml",
              "yarn.lock",
              "package-lock.json",
              ".git"
            )(fname) or vim.fs.dirname(fname)

            if on_dir then
              on_dir(root)
            end

            return root
          end,
          single_file_support = true,
          settings = {
            cucumber = {
              features = { "src/features/**/*.feature" },
              glue = { "src/steps/**/*.ts" },
            },
          },
        },
      },
    },
    init = function()
      vim.filetype.add({
        extension = {
          feature = "cucumber",
        },
      })
    end,
  },
}
