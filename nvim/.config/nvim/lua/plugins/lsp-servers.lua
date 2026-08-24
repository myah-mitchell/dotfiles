-- Language servers that have no dedicated LazyVim lang.* extra: HTML, CSS,
-- Emmet, and Bash. Listing them under lspconfig's `servers` makes LazyVim
-- auto-install them via Mason. All four are Node/npm packages, as is
-- Python's pyright (from the lang.python extra in config/lazy.lua) — Mason
-- would otherwise auto-install pyright unconditionally, so it's explicitly
-- disabled here outside --full instead. Together with PowerShell below and
-- the PHP toolchain gated in config/lazy.lua, this is ~460MB of Mason
-- packages that only make sense on a full IDE workstation (install.sh
-- --full), not a server/shared-box install.
--
-- Node itself always installs (ccstatusline needs it too — see install.sh),
-- so "is node on PATH" can't be used as the --full signal here; install.sh
-- writes ~/.local/state/dotfiles/full-install under --full instead, same as
-- config/lazy.lua checks for the PHP extra.
local full_install = vim.fn.filereadable(vim.fn.expand("~/.local/state/dotfiles/full-install")) == 1

-- PowerShell: needs `pwsh` on PATH (installed self-contained by install.sh
-- --full; bundles its own .NET runtime, nothing else installs it) — checked
-- directly rather than via full_install, since pwsh's presence alone is
-- already an unambiguous --full signal.
local has_pwsh = vim.fn.executable("pwsh") == 1

local servers = {
  -- ruff comes from install.sh (standalone binary on PATH), NOT Mason —
  -- Mason's ruff is pip-based and there's no pip here. mason=false stops
  -- LazyVim from trying (and failing) to install it, and uses ~/.local/bin/ruff.
  -- Always enabled — no Node/pwsh dependency, so not gated on --full.
  ruff = { mason = false },
}

if full_install then
  servers.html = {}
  servers.cssls = {}
  servers.emmet_language_server = {}
  servers.bashls = {}
else
  -- Explicitly disable pyright rather than just omitting it — lang.python
  -- (config/lazy.lua) configures it unconditionally on its own, so `false`
  -- is needed to override that and stop Mason from installing it.
  servers.pyright = false
end

servers.powershell_es = has_pwsh and {} or false

return {
  {
    "neovim/nvim-lspconfig",
    opts = { servers = servers },
  },
}
