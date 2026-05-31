return {
  {
    "catppuccin/nvim",
    name     = "catppuccin",
    priority = 1000,
    opts = {
      flavour          = "mocha",
      background       = { light = "latte", dark = "mocha" },
      transparent_background = false,
      show_end_of_buffer = false,
      term_colors      = true,
      dim_inactive     = { enabled = false },
      no_italic        = false,
      no_bold          = false,
      no_underline     = false,
      integrations = {
        cmp              = true,
        gitsigns         = true,
        nvimtree         = true,
        treesitter       = true,
        notify           = true,
        mini             = { enabled = true, indentscope_color = "" },
        telescope        = { enabled = true },
        which_key        = true,
        mason            = true,
        noice            = true,
        lazy             = true,
        lsp_trouble      = true,
        native_lsp = {
          enabled        = true,
          underlines     = {
            errors       = { "underline" },
            hints        = { "underline" },
            warnings     = { "underline" },
            information  = { "underline" },
          },
        },
      },
    },
  },

  -- Tell LazyVim to use catppuccin
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin" },
  },
}
