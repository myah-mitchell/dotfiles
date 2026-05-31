# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). A single script installs everything, including configs and binaries, to `~/.local/` with no system-wide changes.

## Stack

| Layer | Tool |
|---|---|
| Terminal | [Alacritty](https://alacritty.org/) |
| Shell | [Nushell](https://www.nushell.sh/) |
| Prompt | [Starship](https://starship.rs/) |
| Multiplexer | [Zellij](https://zellij.dev/) |
| Editor | [Neovim](https://neovim.io/) (LazyVim) + [Helix](https://helix-editor.com/) |
| Theme | [Catppuccin Mocha](https://catppuccin.com/) everywhere |
| Font | JetBrainsMonoNL Nerd Font Mono (Light) |

## Quick start

```sh
git clone https://github.com/myah-mitchell/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

That's it. The script downloads all binaries, applies configs via Stow, and on WSL2 also installs Alacritty and the font on the Windows side.

## What install.sh does

1. Downloads pre-built binaries for all tools into `bin/.local/bin/` (gitignored)
2. Downloads Nushell, Starship, Zellij, Neovim, and Helix binaries
3. Runs `stow` on every package to symlink configs into `~`
4. Builds the bat syntax theme cache
5. Installs the Yazi Catppuccin flavor
6. Generates init scripts for atuin, starship, and zoxide
7. **WSL2 only:** installs Alacritty via winget, installs the Nerd Font per-user, and creates a Windows symlink for the Alacritty config

Re-run at any time to apply config changes:

```sh
./install.sh              # apply config changes only (stow --restow)
./install.sh --update     # also update all binaries to latest releases
./install.sh --stow-only  # configs only, skip binary downloads
./install.sh --no-windows # skip Windows/PowerShell steps
```

## Layout

Each directory is a GNU Stow package. Files inside mirror the home directory:

```
dotfiles/
├── nushell/.config/nushell/     → ~/.config/nushell/
├── starship/.config/            → ~/.config/
├── zellij/.config/zellij/       → ~/.config/zellij/
├── nvim/.config/nvim/           → ~/.config/nvim/
├── helix/.config/helix/         → ~/.config/helix/
├── alacritty/.config/alacritty/ → ~/.config/alacritty/
├── git/.gitconfig               → ~/.gitconfig
├── bin/.local/bin/              → ~/.local/bin/   (binaries)
└── ssh/.ssh/config              → ~/.ssh/config
```

## Key bindings

### Zellij

| Keys | Action |
|---|---|
| `` ` `` | Enter prefix mode |
| `` ` `` + `\|` | Vertical split |
| `` ` `` + `-` | Horizontal split |
| `` ` `` + `hjkl` | Navigate panes |
| `` ` `` + `c` | New tab |
| `` ` `` + `p` / `n` | Prev / next tab |
| `` ` `` + `x` | Close pane |
| `` ` `` + `z` | Fullscreen pane |
| `` ` `` + `d` | Detach session |
| `` ` `` + `s` | Scroll mode |
| `Ctrl+hjkl` | Move between Zellij panes (or Neovim splits) |

### Unified pane/split navigation

`Ctrl+h/j/k/l` navigates seamlessly between **Zellij panes** and **Neovim/Helix splits**:

- In a normal terminal pane, `Ctrl+hjkl` moves Zellij focus
- When `nvim` or `hx` is focused, [zellij-autolock](https://github.com/fresh2dev/zellij-autolock) switches Zellij to passthrough mode so the editor receives the keys
- In Neovim, [zellij-nav.nvim](https://github.com/swaits/zellij-nav.nvim) handles the keys: navigates splits internally, and moves to adjacent Zellij panes at the edge

### Clipboard

- Mouse highlight → auto-copies to Windows clipboard
- In Zellij scroll mode, `Ctrl+C` copies the selection
- Neovim uses `unnamedplus` clipboard (WSL2 → `clip.exe`)
- Alacritty `Ctrl+Shift+C/V` for explicit copy/paste

## Packages included

### Core tools (binaries downloaded by install.sh)

`nu` · `starship` · `zellij` · `nvim` · `hx`

### Rust CLI tools

| Tool | Alias | Purpose |
|---|---|---|
| [bat](https://github.com/sharkdp/bat) | `cat` | Syntax-highlighted cat |
| [fd](https://github.com/sharkdp/fd) | `find` | Fast find |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | `grep` | Fast grep |
| [ripgrep-all](https://github.com/phiresky/ripgrep-all) | `rga` | Grep PDFs, archives, etc. |
| [fzf](https://github.com/junegunn/fzf) | — | Fuzzy finder |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | Smart cd |
| [yazi](https://github.com/sxyazi/yazi) | `y` | File manager |
| [lazygit](https://github.com/jesseduffield/lazygit) | `lg` | Git TUI |
| [difftastic](https://github.com/Wilfred/difftastic) | `diff`, `gd` | Structural diff |
| [duf](https://github.com/muesli/duf) | `du` | Disk usage |
| [procs](https://github.com/dalance/procs) | `ps` | Process viewer |
| [rip](https://github.com/nivekuil/rip) | `rm` | Safer rm |
| [tailspin](https://github.com/bensadeh/tailspin) | `tail` | Syntax-highlighted tail |
| [viddy](https://github.com/sachaos/viddy) | `watch` | Watch TUI |
| [bottom](https://github.com/ClementTsang/bottom) | `btm` | System monitor TUI |
| [gping](https://github.com/orf/gping) | `gping` | Graphical ping |
| [trippy](https://github.com/fujiapple852/trippy) | `trip` | Network tracer |
| [sd](https://github.com/chmln/sd) | `sd` | Intuitive find-and-replace |
| [ouch](https://github.com/ouch-org/ouch) | `ouch` | Universal archive tool |
| [atuin](https://github.com/atuinsh/atuin) | — | Shell history |
| [tealdeer](https://github.com/dbrgn/tealdeer) | `tldr` | Fast tldr pages |
| [presenterm](https://github.com/mfontanini/presenterm) | `presenterm` | Terminal slideshows |
| [asciinema](https://github.com/asciinema/asciinema) | `asciinema` | Terminal recording |

### `nr` — call native system binaries

When you need the original system tool instead of the Rust replacement:

```nu
nr ls -la          # /usr/bin/ls
nr du -sh .        # /usr/bin/du
nr rm -rf /tmp/x   # /usr/bin/rm
```

## Notes

- **httm** (file time machine via ZFS snapshots): installed via `cargo install httm` if cargo is available, since no pre-built binary release was confirmed. Alternatively install via your package manager.
- **mosh**: installed via `apt-get` if available (no GitHub release binaries). Usually pre-installed on servers.
- **SSH sockets**: `~/.ssh/sockets/` is created by install.sh but not tracked in git.

## First-time Neovim setup

After install.sh completes:

```sh
nvim
# Inside nvim:
# :LazySync   — installs all plugins
```

Plugins include LazyVim base, Catppuccin theme, zellij-nav.nvim (unified navigation), and opencode.nvim (`<leader>ao` to toggle).
