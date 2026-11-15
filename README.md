# dotfiles

Personal dotfiles and the tools they configure: zsh, Zellij, Neovim (LazyVim), and about 50 command-line tools, all Catppuccin Mocha themed. [dfutil](https://github.com/myah-mitchell/dfutil) installs everything into `~/.local` and links the configs into `$HOME`, with no system-wide changes.

## Contents

- [Stack](#stack)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Presets](#presets)
- [Keeping a machine up to date](#keeping-a-machine-up-to-date)
- [Layout](#layout)
- [Key bindings](#key-bindings)
- [Tools](#tools)
- [Notes](#notes)
- [install.sh](#installsh)
- [License](#license)

## Stack

| Layer | Tool |
| --- | --- |
| Terminal | [Alacritty](https://alacritty.org/) |
| Shell | [zsh](https://www.zsh.org/) |
| Prompt | [Starship](https://starship.rs/) |
| Multiplexer | [Zellij](https://zellij.dev/), with zjstatus and zjhints status bars |
| Editor | [Neovim](https://neovim.io/) (LazyVim) |
| Theme | [Catppuccin Mocha](https://catppuccin.com/) |
| Font | JetBrainsMono Nerd Font (the NF, NFM, and NFP variants, not NL) |

## Prerequisites

- Linux, x86_64 or aarch64, WSL2 included. The Zellij fork this repo pins publishes x86_64 builds only, so aarch64 hosts can't install Zellij yet.
- zsh, git 2.35 or later (for the `zdiff3` merge style), and `curl`, installed through the system package manager.
- A GitHub token in `GITHUB_TOKEN` for a first install, or a `gh auth login`. Unauthenticated GitHub API calls are capped at 60 an hour, and a first install looks up about 50 releases.

## Quick start

1. Download dfutil from its [latest release](https://github.com/myah-mitchell/dfutil/releases/latest) into a temporary directory. This copy only bootstraps: `dfutil apply` installs dfutil into `~/.local/bin` as one of the `base` tools, and refuses to link over a file it didn't put there.

   ```bash
   version=$(curl -fsSL https://api.github.com/repos/myah-mitchell/dfutil/releases/latest | sed -n 's/.*"tag_name": "\(.*\)".*/\1/p')
   boot=$(mktemp -d)
   curl -fsSL "https://github.com/myah-mitchell/dfutil/releases/download/$version/dfutil-$version-$(uname -m)-unknown-linux-musl.tar.gz" \
     | tar -xz -C "$boot" dfutil
   ```

2. Clone this repo to `~/dotfiles` and record this host's presets in `~/.config/dfutil/host.toml`. Add presets after `base` with commas; see [Presets](#presets).

   ```bash
   "$boot/dfutil" init --repo https://github.com/myah-mitchell/dotfiles.git --preset base
   ```

3. Install the tools and link the configs, then remove the bootstrap copy:

   ```bash
   "$boot/dfutil" apply
   rm -r "$boot"
   ```

   Any real file already at a config's path is moved aside as `<path>.bak.<timestamp>`.

4. Open a new terminal. zsh starts Zellij, and the prompt, history search (`Ctrl+R`), and completions load. Neovim installs its plugins the first time it opens.

## Presets

| Preset | Adds |
| --- | --- |
| `base` | dfutil itself, the core and CLI tools, Zellij and zsh plugins, themes, the Nerd Font on native Linux, and every config package except `nushell` |
| `claude` | Claude Code, Node.js, ccstatusline, and claude-swap |
| `windows` | Under WSL2 only: Alacritty and the Nerd Font on the Windows side, and a link from Windows Alacritty's config to this repo's |
| `full` | `claude` and `windows`, plus PowerShell and Neovim's heavier language servers (about 460MB) |
| `nushell` | Nushell as an optional second shell, with its config. zsh stays the login shell |
| `cargo` | Builds Rust tools from source instead of downloading them, and adds a weekly timer that cleans stale `target/` directories |

Use `full` on a Neovim workstation, `claude` on a machine that only needs Claude Code, and `base` alone on servers. Change a host's presets with `dfutil preset select <name>` or `dfutil preset deselect <name>`, then run `dfutil apply`.

## Keeping a machine up to date

| Command | Does |
| --- | --- |
| `dfutil` | Opens the terminal UI: tools with their installed and available versions, presets, palettes, and dotfiles |
| `dfutil status` | Lists every tool with its installed version, the newest version its pin allows, and the pin |
| `dfutil update` | Pulls this repo, then installs whatever changed |
| `dfutil sync` | Copies local edits to rendered files back into their templates, pulls, and redeploys |
| `dfutil schedule enable` | Runs `dfutil update` on a timer |
| `dfutil rollback <tool>` | Switches a tool back to the version it had before its last install |

## Layout

Each top-level directory with a `[packages.<name>]` entry in `dfutil.toml` is a package. dfutil links every file in it to the same path under `$HOME`:

```text
zsh/.zshrc                      -> ~/.zshrc
zsh/.config/zsh/aliases.zsh     -> ~/.config/zsh/aliases.zsh
zellij/.config/zellij/          -> ~/.config/zellij/
nvim/.config/nvim/              -> ~/.config/nvim/
git/.gitconfig                  -> ~/.gitconfig
ssh/.ssh/config                 -> ~/.ssh/config
```

A file ending in `.tmpl` is rendered with this host's variables and palette, and the rendered copy is linked without the suffix. A package's `.linkignore` lists files that aren't linked, one glob per line.

| Path | Holds |
| --- | --- |
| `dfutil.toml` | Tools, pins, packages, and presets |
| `palettes/` | Catppuccin Mocha and Latte color names for templates. `dfutil palette set latte` recolors the templated files only |
| `scripts/` | Install helpers that dfutil's script tools run, plus `yubikey-ssh-keys.sh` |
| `.github/` | The weekly workflow that opens a PR when a pinned version falls behind upstream |

## Key bindings

### Zellij

Zellij's default bindings apply, with these changes:

| Keys | Action |
| --- | --- |
| `Ctrl+h`, `Ctrl+j`, `Ctrl+k`, `Ctrl+l` | Move between Zellij panes, and between Neovim splits |
| `Alt+h`, `Alt+l` | Move focus left or right, onto the next tab at the edge |
| `Alt+j`, `Alt+k` | Move focus down or up |
| `Ctrl+w` | Move mode |
| `Ctrl+y` | Copy the selection |
| `Ctrl+g` | Lock or unlock Zellij (full passthrough to the focused app) |

Zellij's other modes keep their default keys, such as `Ctrl+p` for panes, `Ctrl+t` for tabs, `Ctrl+s` for scroll and search, and `Ctrl+o` for sessions. Its tmux mode is turned off, so `Ctrl+b` reaches the shell.

In scroll and search mode, `y` or `Ctrl+C` copies the selection and stays in the mode.

The bottom bars show the mode, tabs, weather, system load, battery, and the time (zjstatus), and keybinding hints for the current mode (zjhints).

### Unified pane and split navigation

`Ctrl+h/j/k/l` moves across Zellij panes and Neovim splits as one grid:

- In a terminal pane, the keys move Zellij focus.
- When nvim, fzf, zoxide, atuin, or tmux is focused, [zellij-autolock](https://github.com/fresh2dev/zellij-autolock) locks Zellij so the app gets the keys.
- In Neovim, [zellij-nav.nvim](https://github.com/swaits/zellij-nav.nvim) moves between splits, and at the edge of the window moves to the next Zellij pane.

### zsh

| Keys | Action |
| --- | --- |
| `Ctrl+R` | Search history (atuin) |
| `Ctrl+F` | Pick a file with fzf and insert its path |

## Tools

### Shell and editor

`starship`, `zellij`, `nvim`, `atuin`, `zoxide`, `carapace`, and `yazi`. With the `nushell` preset, also `nu`.

### CLI tools

| Tool | Alias | Purpose |
| --- | --- | --- |
| [bat](https://github.com/sharkdp/bat) | `cat` | Syntax-highlighted cat |
| [fd](https://github.com/sharkdp/fd) | `find` | Fast find |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | `grep` | Fast grep |
| [ripgrep-all](https://github.com/phiresky/ripgrep-all) | | Grep PDFs, archives, and more (x86_64 only) |
| [eza](https://github.com/eza-community/eza) | `ls` | `ls` replacement |
| [fzf](https://github.com/junegunn/fzf) | | Fuzzy finder |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | Frecency-based cd |
| [yazi](https://github.com/sxyazi/yazi) | `y` | File manager |
| [lazygit](https://github.com/jesseduffield/lazygit) | `lg` | Git TUI |
| [serpl](https://github.com/yassinebridi/serpl) | | Search and replace across files |
| [difftastic](https://github.com/Wilfred/difftastic) | `diff` | Structural diff, and git's default diff |
| [delta](https://github.com/dandavison/delta) | `gdd`, `gdds` | Syntax-highlighting pager for unified diffs |
| [diffnav](https://github.com/dlvhdr/diffnav) | `gdn`, `gdns` | File-tree diff browser built on delta |
| [procs](https://github.com/dalance/procs) | `ps` | Process viewer (x86_64 only) |
| [tailspin](https://github.com/bensadeh/tailspin) | `tail` | Highlighted log viewer |
| [viddy](https://github.com/sachaos/viddy) | `watch` | `watch` with history |
| [bottom](https://github.com/ClementTsang/bottom) (`btm`) | | System monitor |
| [gping](https://github.com/orf/gping) | | Ping with a graph |
| [trippy](https://github.com/fujiapple852/trippy) (`trip`) | | Network tracer |
| [sd](https://github.com/chmln/sd) | | Find and replace, not a `sed` alias (x86_64 only) |
| [choose](https://github.com/theryangeary/choose) | | `cut` and `awk` alternative (x86_64 only) |
| [ouch](https://github.com/ouch-org/ouch) | | Compress and decompress any format |
| [7-Zip](https://github.com/ip7z/7zip) (`7zz`) | | Archive tool |
| [jq](https://github.com/jqlang/jq) | | JSON processor |
| [glow](https://github.com/charmbracelet/glow) | | Markdown renderer |
| [mdcat](https://github.com/BIRSAx2/mdcat) | | Markdown renderer with images and links (x86_64 only) |
| [tealdeer](https://github.com/tealdeer-rs/tealdeer) (`tldr`) | | tldr pages |
| [presenterm](https://github.com/mfontanini/presenterm) | | Terminal slideshows (x86_64 only) |
| [asciinema](https://github.com/asciinema/asciinema) | | Terminal recording |
| [ruff](https://github.com/astral-sh/ruff) and [uv](https://github.com/astral-sh/uv) | | Python linting and packaging |
| [tree-sitter](https://github.com/tree-sitter/tree-sitter) | | Parser CLI for Neovim's treesitter |

To run the system binary instead of an alias, use zsh's `command` builtin, for example `command ls -la`.

## Notes

- Neovim's AI integration is the Claude Code sidebar, [claudecode.nvim](https://github.com/coder/claudecode.nvim), on `<leader>ac`.
- VS Code's integrated terminal gets a plain shell, without Zellij.
- One ssh-agent runs per host, at `~/.ssh/agent/<host>.sock`, shared by every shell.
- To retrieve SSH keys stored on a YubiKey, run `scripts/yubikey-ssh-keys.sh` with the key plugged in. Under WSL2 the key has to be passed through with usbipd first; see `CLAUDE.md`.
- `mosh` has no release binaries, so install it through the system package manager if you want it.

## install.sh

`install.sh` is the older installer, kept while fleet hosts still deploy this repo through it. It installs the same tools and links the same packages without dfutil, and `./install.sh --help` lists its flags. Don't run both on one machine: they keep separate state and both write to `~/.local/bin`.

## License

Copyright (c) 2026 Myah Mitchell. Licensed under the [MIT License](LICENSE).
