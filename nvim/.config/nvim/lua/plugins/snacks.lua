return {
  "folke/snacks.nvim",
  opts = {
    image = { enabled = false },
    -- This dotfiles repo is almost entirely dot-directories (.config/.local) and
    -- dotfiles (.bashrc/.gitconfig), so the explorer must show hidden entries or
    -- most folders look empty. `ignored` stays off so downloaded binaries under
    -- bin/.local/ don't flood the tree — toggle it at runtime with `I` if needed.
    picker = {
      sources = {
        explorer = { hidden = true },
      },
    },
    -- VSCode-style bottom-docked terminal (<c-/> toggles it).
    -- Runs a plain shell; the Nushell zellij-autostart guard (checks $NVIM)
    -- keeps it from spawning a nested Zellij session inside the nvim terminal.
    terminal = {
      win = { position = "bottom", height = 0.3 },
    },
  },
}
