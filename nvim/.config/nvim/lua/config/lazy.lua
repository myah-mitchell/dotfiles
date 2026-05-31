-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- LazyVim base distribution
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- LazyVim extras (opt-in)
    { import = "lazyvim.plugins.extras.editor.telescope" },
    { import = "lazyvim.plugins.extras.editor.harpoon2" },
    { import = "lazyvim.plugins.extras.coding.luasnip" },
    { import = "lazyvim.plugins.extras.coding.mini-surround" },
    { import = "lazyvim.plugins.extras.util.mini-hipatterns" },

    -- Custom plugins
    { import = "plugins" },
  },
  defaults = {
    lazy    = false,
    version = false,
  },
  install = {
    colorscheme = { "catppuccin", "habamax" },
  },
  rocks = { enabled = false },
  checker = {
    enabled = true,
    notify  = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "matchit", "matchparen", "netrwPlugin",
        "tarPlugin", "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})
