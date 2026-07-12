-- The Zellij zjstatus bar already renders mode / git / clock / system info, and
-- incline.nvim (see incline.lua) labels each window — so LazyVim's bottom
-- statusline is pure duplication. Disable it and hide the statusline row
-- entirely (laststatus is set to 0 in config/options.lua) to reclaim the space.
-- Revert: delete this file and reset laststatus to 3.
return {
  { "nvim-lualine/lualine.nvim", enabled = false },
}
