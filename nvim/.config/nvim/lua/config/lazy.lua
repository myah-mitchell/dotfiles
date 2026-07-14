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
    { import = "lazyvim.plugins.extras.editor.snacks_explorer" },
    { import = "lazyvim.plugins.extras.editor.telescope" },
    { import = "lazyvim.plugins.extras.editor.harpoon2" },
    { import = "lazyvim.plugins.extras.coding.luasnip" },
    { import = "lazyvim.plugins.extras.coding.mini-surround" },
    { import = "lazyvim.plugins.extras.util.mini-hipatterns" },
    -- Sticky scroll: pins the enclosing scope (fn/class/loop) to the top of the
    -- window so you always see where you are in the file (VSCode "Sticky Scroll").
    { import = "lazyvim.plugins.extras.ui.treesitter-context" },
    -- Language support. Rust uses cargo/rust-analyzer; Python and PHP LSP servers
    -- (basedpyright/ruff, intelephense) install via the Node in ~/.local. HTML,
    -- CSS, Emmet and Bash servers are added manually in plugins/lsp-servers.lua
    -- (no dedicated lang.* extras exist for them). PowerShell's server
    -- (powershell_es) is there too — it runs on the self-contained pwsh that
    -- install.sh installs, which bundles its own .NET runtime.
    { import = "lazyvim.plugins.extras.lang.rust" },
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.php" },
    -- Markdown: render-markdown.nvim (in-buffer rendering) plus the marksman
    -- LSP, markdownlint-cli2/prettier/markdown-toc (Mason/Node) and the
    -- markdown-preview.nvim browser preview (<leader>cp). Toggle rendering with
    -- <leader>um.
    { import = "lazyvim.plugins.extras.lang.markdown" },

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
