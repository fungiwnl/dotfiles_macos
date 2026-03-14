return {
  -- keep gruvbox available as a manual fallback via :colorscheme gruvbox
  { "ellisonleao/gruvbox.nvim" },

  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      background = {
        light = "latte",
        dark = "mocha",
      },
      transparent_background = true,
      float = {
        transparent = false,
        solid = false,
      },
      term_colors = true,
      auto_integrations = true,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
      },
      custom_highlights = function(colors)
        return {
          NormalFloat = { bg = colors.base },
          FloatBorder = { fg = colors.surface2, bg = colors.base },
          Pmenu = { bg = colors.mantle },
          PmenuSel = { bg = colors.surface0 },
          TelescopeBorder = { fg = colors.surface2, bg = colors.base },
          TelescopePromptNormal = { bg = colors.mantle },
          TelescopePromptBorder = { fg = colors.surface1, bg = colors.mantle },
          TelescopeResultsNormal = { bg = colors.base },
          TelescopeResultsBorder = { fg = colors.surface1, bg = colors.base },
          TelescopePreviewNormal = { bg = colors.base },
          TelescopePreviewBorder = { fg = colors.surface1, bg = colors.base },
        }
      end,
    },
  },

  -- default to Catppuccin Mocha so Neovim matches Ghostty/OpenCode
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
