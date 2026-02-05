-- lua/plugins/cucumber.lua
return {
  -- LSP config
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        cucumber_language_server = {
          filetypes = { "cucumber", "feature" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern(
              "cucumber.yml",
              "cucumber.yaml",
              ".cucumber.yml",
              ".cucumber.yaml",
              "package.json"
            )(fname)
          end,
          settings = {
            cucumber = {
              features = { "**/*.feature" },
              glue = {
                "src/steps/**/*.ts",
                "src/steps/*steps.ts",
              },
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
