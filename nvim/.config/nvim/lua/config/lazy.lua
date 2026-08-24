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

-- Set by install.sh's --full flag (~/.local/state/dotfiles/full-install) —
-- see lua/plugins/lsp-servers.lua for the full explanation. Node.js itself
-- always installs (ccstatusline needs it too), so this marker — not "is node
-- on PATH" — is what distinguishes a full IDE workstation from a minimal
-- install; it gates whether the ~460MB PHP toolchain (intelephense/phpactor/
-- php-cs-fixer/phpcs) gets pulled in here.
local full_install = vim.fn.filereadable(vim.fn.expand("~/.local/state/dotfiles/full-install")) == 1

local spec = {
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
  -- Language support. Rust uses cargo/rust-analyzer (no Node/pwsh dependency,
  -- always on). Python's ruff comes from install.sh's standalone binary
  -- (always on); its pyright LSP is Node/Mason-based and disabled outside
  -- --full in lsp-servers.lua. HTML, CSS, Emmet and Bash servers are added
  -- manually in plugins/lsp-servers.lua (no dedicated lang.* extras exist for
  -- them) and gated there the same way. PowerShell's server (powershell_es)
  -- is also there, gated on `vim.fn.executable("pwsh")` directly rather than
  -- this marker, since nothing else installs pwsh.
  { import = "lazyvim.plugins.extras.lang.rust" },
  { import = "lazyvim.plugins.extras.lang.python" },
  -- Markdown: render-markdown.nvim (in-buffer rendering) plus the marksman
  -- LSP, markdownlint-cli2/prettier/markdown-toc (Mason/Node) and the
  -- markdown-preview.nvim browser preview (<leader>cp). Toggle rendering with
  -- <leader>um. Left ungated: markdown editing is common enough on any
  -- machine to not tie it to --full, and its Node tooling is comparatively
  -- small (~30MB) next to the PHP/PowerShell/web-LSP chunks that are gated.
  { import = "lazyvim.plugins.extras.lang.markdown" },

  -- Custom plugins
  { import = "plugins" },
}

-- PHP (intelephense/phpactor/php-cs-fixer/phpcs, ~160MB of Mason packages) —
-- only on a full IDE workstation. See full_install comment above.
if full_install then
  table.insert(spec, { import = "lazyvim.plugins.extras.lang.php" })
end

require("lazy").setup({
  spec = spec,
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
