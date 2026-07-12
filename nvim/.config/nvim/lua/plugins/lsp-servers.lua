-- Language servers that have no dedicated LazyVim lang.* extra: HTML, CSS,
-- Emmet, and Bash. Listing them under lspconfig's `servers` makes LazyVim
-- auto-install them via Mason (all four are Node/npm packages — see the Node
-- installer in install.sh). Rust/Python/PHP come from their lang.* extras
-- (config/lazy.lua); PowerShell is treesitter-only until a .NET runtime exists.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        html = {},
        cssls = {},
        emmet_language_server = {},
        bashls = {},
        -- ruff comes from install.sh (standalone binary on PATH), NOT Mason —
        -- Mason's ruff is pip-based and there's no pip here. mason=false stops
        -- LazyVim from trying (and failing) to install it, and uses ~/.local/bin/ruff.
        ruff = { mason = false },
      },
    },
  },
}
