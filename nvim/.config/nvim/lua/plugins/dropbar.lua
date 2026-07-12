-- dropbar.nvim — VSCode-style breadcrumbs in each window's winbar (top-left):
-- a clickable folder › file › Symbol › Symbol trail showing where you are.
-- Symbol sources fall back to treesitter when no LSP is attached, so it works
-- for all languages right now (before Node-based LSP servers are installed).
-- Because dropbar owns the winbar and incline is a floating window (top-right),
-- the two don't collide — dropbar carries the name/path/location, so incline
-- (see incline.lua) shows file *info* instead.
return {
  "Bekaboo/dropbar.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    bar = {
      -- don't show the bar in special/no-name buffers
      enable = function(buf, win, _)
        if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
          return false
        end
        local b = vim.bo[buf]
        return b.buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" and not b.filetype:match("^snacks_")
      end,
    },
  },
}
