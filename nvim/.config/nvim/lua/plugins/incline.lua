-- incline.nvim — tiny floating per-window label (filename + icon + modified dot).
-- Deliberately minimal: the zjstatus bar in Zellij already carries mode / git /
-- clock / system info, so nothing here duplicates that. Pairs with lualine being
-- disabled (see lualine.lua) — incline labels each split, zjstatus is the status bar.
return {
  "b0o/incline.nvim",
  event = "VeryLazy",
  dependencies = { "catppuccin/nvim", "nvim-tree/nvim-web-devicons" },
  config = function()
    local mocha = require("catppuccin.palettes").get_palette("mocha")
    require("incline").setup({
      hide = { cursorline = true },
      window = {
        margin = { vertical = 0, horizontal = 1 },
        padding = 1,
        placement = { horizontal = "right", vertical = "top" },
      },
      render = function(props)
        local bufname = vim.api.nvim_buf_get_name(props.buf)
        local filename = bufname == "" and "[No Name]" or vim.fn.fnamemodify(bufname, ":t")
        local icon, color = require("nvim-web-devicons").get_icon_color(filename)
        local modified = vim.bo[props.buf].modified
        return {
          icon and { icon .. " ", guifg = color } or "",
          {
            filename,
            gui = modified and "bold,italic" or "bold",
            guifg = props.focused and mocha.text or mocha.overlay1,
          },
          modified and { " ●", guifg = mocha.peach } or "",
        }
      end,
    })
  end,
}
