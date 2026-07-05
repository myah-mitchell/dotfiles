# dotfiles

Personal dotfiles deployed via a small hand-rolled symlinker (see [Layout](#layout)). A single script installs everything, including configs and binaries, to `~/.local/` with no system-wide changes (beyond two narrow exceptions: `mosh`, and upgrading `git` itself via PPA when it's too old).

## Stack

| Layer | Tool |
|---|---|
| Terminal | [Alacritty](https://alacritty.org/) |
| Shell | [Nushell](https://www.nushell.sh/) |
| Prompt | [Starship](https://starship.rs/) |
| Multiplexer | [Zellij](https://zellij.dev/) (+ [zjstatus](https://github.com/dj95/zjstatus) status bar) |
| Editor | [Neovim](https://neovim.io/) (LazyVim) |
| Theme | [Catppuccin Mocha](https://catppuccin.com/) everywhere |
| Font | JetBrainsMono Nerd Font (NF/NFM/NFP — not the NL/no-ligature variant) |

## Quick start

```sh
git clone https://github.com/myah-mitchell/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

That's it. The script downloads all binaries, symlinks configs into `~`, and on WSL2 also installs Alacritty and the font on the Windows side.

Set `GITHUB_TOKEN` in your environment first if doing a fresh install — unauthenticated GitHub API requests are capped at 60/hr, and this script checks 25+ tools' latest releases.

## What install.sh does

1. Downloads pre-built binaries for all tools into `bin/.local/bin/` (gitignored)
2. Downloads Nushell, Starship, Zellij, and Neovim binaries
3. Symlinks (or, with `--copy`, copies) every package directory into `~`, one file at a time
4. Prunes any dangling symlinks left behind by files that were renamed/removed from the repo
5. Registers Nushell plugins and runs a headless `:Lazy sync` for Neovim
6. Generates init scripts for atuin, starship, zoxide, and carapace
7. Installs Yazi's Catppuccin flavor and plugin set
8. Downloads the Zellij plugins that back the status bar and navigation (`zjstatus`, `zellij-autolock`, `zellij-newtab-plus`), builds `zjstatus-hints` from source, and pre-approves their Zellij permissions
9. **WSL2 only:** installs Alacritty via winget, installs the Nerd Font per-user, and creates a Windows symlink for the Alacritty config. On native Linux/macOS it downloads the font directly instead.

Re-run at any time to apply config changes:

```sh
./install.sh              # full run: binaries + config links
./install.sh --update     # force re-download/rebuild all tools to latest, even if current
./install.sh --link       # skip binary downloads, only re-link configs (fast)
./install.sh --copy       # copy configs instead of symlinking (useful on NTFS or shared servers)
./install.sh --remove     # remove all deployed symlinks from $HOME and exit (binaries untouched)
./install.sh --no-windows # skip Windows/PowerShell steps
./install.sh --cargo      # build Rust tools from source via cargo instead of downloading (slow)
```

## Layout

Each top-level directory is a package. `install.sh` walks it and symlinks every file into the matching path under `$HOME` — files mirror the home directory layout:

```
dotfiles/
├── nushell/.config/nushell/     → ~/.config/nushell/
├── starship/.config/            → ~/.config/
├── zellij/.config/zellij/       → ~/.config/zellij/
├── nvim/.config/nvim/           → ~/.config/nvim/
├── alacritty/.config/alacritty/ → ~/.config/alacritty/
├── git/.gitconfig               → ~/.gitconfig
├── bash/.bashrc, .bash_profile  → ~/.bashrc, ~/.bash_profile
├── bin/.local/bin/              → ~/.local/bin/   (binaries)
└── ssh/.ssh/config              → ~/.ssh/config
```

A package can drop a `.linkignore` file in its root (one glob per line) to exclude files that shouldn't be symlinked — e.g. `yazi/.linkignore` excludes the flavors/plugins directories, since those are managed at runtime by `ya pkg` instead.

## Key bindings

### Zellij

| Keys | Action |
|---|---|
| `` ` `` | Enter prefix (`tmux`) mode |
| `` ` `` + `\` | Vertical split |
| `` ` `` + `-` | Horizontal split |
| `` ` `` + `hjkl` | Navigate panes |
| `` ` `` + `H`/`J`/`K`/`L` | Move pane |
| `` ` `` + `c` | New tab (floating picker, zoxide-aware) |
| `` ` `` + `p` / `n` | Prev / next tab |
| `` ` `` + `[` / `]` | Prev / next tab (alternate) |
| `` ` `` + `1`-`9` | Jump to tab N |
| `` ` `` + `x` | Close pane |
| `` ` `` + `z` | Fullscreen pane |
| `` ` `` + `f` | Toggle floating panes |
| `` ` `` + `,` | Rename tab |
| `` ` `` + `d` | Detach session |
| `` ` `` + `s` | Scroll mode |
| `` ` `` + `/` | Search |
| `` ` `` + `o` | Session mode |
| `Ctrl+hjkl` | Move between Zellij panes (or Neovim splits) |
| `Ctrl+g` | Emergency toggle into/out of locked (full-passthrough) mode |

The status bar (bottom, via zjstatus) shows the current mode, open tabs, weather/system/battery info, and the datetime; a second bar shows context-sensitive keybinding hints (via zjstatus-hints).

### Unified pane/split navigation

`Ctrl+h/j/k/l` navigates seamlessly between **Zellij panes** and **Neovim splits**:

- In a normal terminal pane, `Ctrl+hjkl` moves Zellij focus
- When `nvim`, `fzf`, `zoxide`, or `atuin` is focused, [zellij-autolock](https://github.com/fresh2dev/zellij-autolock) switches Zellij to passthrough mode so the app receives the keys
- In Neovim, [zellij-nav.nvim](https://github.com/swaits/zellij-nav.nvim) handles the keys: navigates splits internally, and moves to adjacent Zellij panes at the edge

### Clipboard

- Mouse highlight → auto-copies to Windows clipboard
- In Zellij scroll mode, `Ctrl+C` copies the selection
- Neovim uses `unnamedplus` clipboard (WSL2 → `clip.exe`)
- Alacritty `Ctrl+Shift+C/V` for explicit copy/paste

## Packages included

### Core tools (binaries downloaded by install.sh)

`nu` · `starship` · `zellij` · `nvim`

### CLI tools

| Tool | Alias | Purpose |
|---|---|---|
| [bat](https://github.com/sharkdp/bat) | `cat` | Syntax-highlighted cat |
| [fd](https://github.com/sharkdp/fd) | `find` | Fast find |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | `grep` | Fast grep |
| [ripgrep-all](https://github.com/phiresky/ripgrep-all) | — | Grep PDFs, archives, etc. |
| [eza](https://github.com/eza-community/eza) | — | Modern `ls` replacement (installed, not yet aliased over `ls`) |
| [fzf](https://github.com/junegunn/fzf) | — | Fuzzy finder (also bound to `Ctrl+F` in Nushell) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | Smart cd |
| [yazi](https://github.com/sxyazi/yazi) | `y` | File manager |
| [lazygit](https://github.com/jesseduffield/lazygit) | `lg` | Git TUI |
| [serpl](https://github.com/yassinebridi/serpl) | — | TUI search-and-replace across files |
| [difftastic](https://github.com/Wilfred/difftastic) | `diff` | Structural diff (also `GIT_EXTERNAL_DIFF`) |
| [procs](https://github.com/dalance/procs) | `ps` | Process viewer |
| [tailspin](https://github.com/bensadeh/tailspin) | `tail` | Syntax-highlighted tail |
| [viddy](https://github.com/sachaos/viddy) | `watch` | Watch TUI |
| [bottom](https://github.com/ClementTsang/bottom) | `btm` | System monitor TUI (standalone, not a `top` alias) |
| [gping](https://github.com/orf/gping) | `gping` | Graphical ping |
| [trippy](https://github.com/fujiapple852/trippy) | `trip` | Network tracer |
| [sd](https://github.com/chmln/sd) | — | Intuitive find-and-replace (standalone, not a `sed` alias) |
| [choose](https://github.com/theryangeary/choose) | — | Human-friendly cut/awk alternative |
| [ouch](https://github.com/ouch-org/ouch) | — | Universal archive tool |
| [7-Zip (7zz)](https://github.com/ip7z/7zip) | — | Archive tool |
| [jq](https://github.com/jqlang/jq) | — | JSON processor |
| [glow](https://github.com/charmbracelet/glow) | — | Markdown renderer in the terminal |
| [carapace](https://github.com/carapace-sh/carapace-bin) | — | Multi-shell argument completions |
| [atuin](https://github.com/atuinsh/atuin) | — | Shell history (SQLite-backed, per-session isolated) |
| [tealdeer](https://github.com/tealdeer-rs/tealdeer) | `tldr` | Fast tldr pages |
| [presenterm](https://github.com/mfontanini/presenterm) | — | Terminal slideshows |
| [asciinema](https://github.com/asciinema/asciinema) | — | Terminal recording |

### `nr` — call native system binaries

When you need the original system tool instead of the Rust replacement:

```nu
nr ls -la          # /usr/bin/ls
nr du -sh .        # /usr/bin/du
nr rm -rf /tmp/x   # /usr/bin/rm
```

## Notes

- **mosh**: installed via `apt-get` if available (no GitHub release binaries). Usually pre-installed on servers.
- **git**: on Ubuntu/Debian with git older than 2.35, `install.sh` upgrades it via the git-core PPA — the only other exception to the "no system package installs" rule, needed for `zdiff3` merge style.
- **zjstatus-hints**: has no usable upstream release, so `install.sh` builds it from source (requires cargo + the `wasm32-wasip1` target) off a temporary community fork branch rather than upstream `main`. See `install.sh` for details if the hints bar stops building.
- **SSH sockets**: `~/.ssh/sockets/` is created by install.sh but not tracked in git.

## First-time Neovim setup

`install.sh` already runs a headless `:Lazy sync` automatically. If plugins didn't finish installing (e.g. it timed out on a slow connection), finish manually:

```sh
nvim
# Inside nvim:
# :Lazy sync
```

Plugins include LazyVim base, Catppuccin theme, zellij-nav.nvim (unified navigation), and opencode.nvim (`<leader>ao` to toggle).
