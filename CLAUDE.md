# CLAUDE.md — Architecture & Design Decisions

This file is for Claude Code sessions. It captures the *why* behind this dotfiles repo so future sessions can make changes without reading every config file.

---

## Zellij mode architecture

Three modes are in play — do not conflate them:

| Mode | What it is | When active |
|---|---|---|
| `normal` | Our main operating mode (custom) | Default — all terminal use |
| `tmux` | Prefix-active layer (custom) | After backtick is pressed |
| `locked` | Zellij built-in full-passthrough | Managed by zellij-autolock (or `Ctrl g` manually) |

**`normal` mode** intercepts `Ctrl+hjkl` for pane navigation and backtick to enter `tmux` mode. All other keys pass to the terminal.

**`tmux` mode** is the prefix layer (like tmux's `C-b`). Backtick is the prefix. Most actions return to `normal` after executing. Key bindings: `\`/`-` split panes, `c` opens a new tab via the zellij-newtab-plus plugin (floating picker with zoxide-backed directory jump), `p`/`n` prev/next tab, `[`/`]` alternate prev/next tab, `1`-`9` jump to tab, `hjkl` move focus, `H`/`J`/`K`/`L` move pane, `x` close, `z` fullscreen, `f` toggle floating, `e` toggle embed/floating, `w` toggle pane frames, `,` rename tab, `d` detach, `q` quit, `o` → session mode, `r` → resize mode, `s` → scroll mode, `/` → search.

**`locked` mode** is Zellij's built-in full passthrough — every keystroke goes directly to the focused pane. We never enter it manually except via the `Ctrl g` emergency-escape binding (bound in `shared_except "locked" "tmux"` to enter, and inside `locked` to exit). `zellij-autolock` switches to it automatically based on the focused process, then exits it when that process closes. Do not add keybindings to `locked` beyond the escape hatch.

---

## Unified Ctrl+hjkl navigation

Two components work together:

1. **`fresh2dev/zellij-autolock`** (Zellij plugin) — watches the focused process; switches Zellij to built-in `locked` mode when `nvim|hx|fzf|zoxide|atuin` are focused (see `triggers` in `zellij/.config/zellij/config.kdl`), back to `normal` when they close.

2. **`swaits/zellij-nav.nvim`** (Neovim plugin) — handles `Ctrl+hjkl` inside Neovim. Navigates splits internally; at the window edge, calls `zellij action move-focus` to move to the adjacent Zellij pane.

Result: `Ctrl+hjkl` moves between Zellij panes in the terminal, moves between Neovim splits inside nvim, and crosses the nvim/Zellij boundary seamlessly.

---

## Zellij status bar & plugin loading

`zellij/.config/zellij/layouts/default.kdl` renders a `zjstatus`-based status bar (mode pill, tab pills, weather/sysinfo/battery command pills, datetime, username/hostname) plus a `zjstatus-hints` keybinding-hints bar. Both are themed inline in `config.kdl`'s `plugins { zjstatus { ... } }` block with the Catppuccin Mocha hex palette — there is no shared palette file for zjstatus, so if the theme changes, update it here too (see [Theme](#theme)).

**Why plugins load from a local file, not `https://`:** `config.kdl` references plugins as `file:~/.local/share/zellij/plugins/<name>.wasm`. `install.sh` downloads each `.wasm` once into `bin/.local/share/zellij/plugins/` (symlinked into `~/.local/share/zellij/plugins/` by `link_package`) and pins the version alongside the other tools in `.versions`. A live `https://` fetch (or a dead pinned tag) would block *every new terminal*, since these plugins load on every `zellij_autostart` — not just once. Versions are tracked in the `ZELLIJ_PLUGINS` array in `install.sh` and must be bumped in lockstep with the plugin names/tags used in `config.kdl`.

Plugins currently pinned this way: `zellij-autolock` (fresh2dev, tag-based release), `zjstatus` (dj95, tag-based release), `zellij-newtab-plus` (AlexZasorin, tag-based release, powers the `c` new-tab binding above).

**`zjstatus-hints` is a special case:** its only tagged release (v0.1.4) is ~11 months stale, so `install.sh`'s `build_zjstatus_hints()` compiles it from source instead, tracked by commit SHA rather than a version tag. It currently builds from a **temporary fork branch** (`ultranity/zjstatus-hints@feat/zellij-0.44.2-and-customizable-hints`) rather than upstream `b0o/zjstatus-hints@main` — there's a commented-out fallback to a different fork (`AdamsGH`) directly above it in the script. Revert to upstream once the customizable-hints changes land there; check `install.sh` for the current TODO comment before assuming the fork is still needed. Building it requires `rustup target add wasm32-wasip1`, which only happens if cargo is available (`--cargo`, or any prior Rust install).

**Plugin permission pre-seeding:** each plugin's `request_permission()` call needs one-time interactive y/n approval, rendered in its own pane. Since `zjstatus`/`zellij-autolock` live in unfocused size-1 borderless panes, that prompt is easy to never see — the plugin then silently sits inert. `install.sh` pre-writes grants to `~/.cache/zellij/permissions.kdl` (append-only — never clobbers grants for other plugins) so this never blocks a fresh install. If you bump a plugin version and it starts requesting new permission scopes, update the matching entry in `ZELLIJ_PLUGIN_PERMISSIONS` in `install.sh`.

---

## Nushell: env.nu vs config.nu split

Nushell enforces a hard separation:

- **`env.nu`** — environment variables only. No output, no aliases, no function definitions. Runs before `config.nu`.
- **`config.nu`** — everything else: `$env.config`, functions, sourcing init scripts, zellij autostart. Aliases live separately in `autoload/aliases.nu`, auto-sourced by Nushell's autoload directory.

**Why static source paths for zoxide/atuin/starship/carapace:** Nushell parses `source` calls at parse time, not runtime. The path must be a bare literal — it cannot be a `let` variable, a `const` expression using `$nu` fields, or any runtime value. Use bare `~` paths directly in `source` (e.g. `source ~/.local/share/zoxide/init.nu`). `install.sh` generates init scripts to fixed known paths, and `config.nu` sources those fixed paths:

```
~/.local/share/atuin/init.nu       ← generated by: atuin init nu --disable-up-arrow
~/.local/share/zoxide/init.nu      ← generated by: zoxide init nushell
~/.cache/starship/init.nu          ← generated by: starship init nu
~/.cache/carapace/init.nu          ← generated by: carapace _carapace nushell
```

If you need to add another tool that generates a shell init script, follow this same pattern.

**History:** `config.nu`'s `history` block sets `file_format: "sqlite"` (required for atuin), `sync_on_enter: true`, and `isolation: true` — each shell session only sees its own history entries; commands run in other panes/tabs don't show up in this session's history menu (search across all sessions via atuin instead). If you're debugging "why isn't my other pane's command showing in history," this is why.

---

## Config deployment: hand-rolled linker

`install.sh` deploys configs with its own `link_package()`/`remove_package()`/`prune_stale_symlinks()` functions, which walk each package directory and symlink (or, with `--copy`, copy) every file into the matching path under `$HOME`, one file at a time.

```
~/.local/bin/bat  →  ~/dotfiles/bin/.local/bin/bat   (symlink created by link_package)
                               ↑
                      actual binary (gitignored, downloaded by install.sh)
```

Key behaviors specific to this hand-rolled linker:
- **`PACKAGES` array** in `install.sh` lists the top-level package dirs: `bin bash nushell starship zellij nvim git ripgrep bat yazi atuin lazygit tealdeer ssh alacritty`. Adding a new package means adding its directory name here.
- **`.linkignore`** — a package can drop a `.linkignore` file in its root (glob per line, `#` comments) to exclude files that shouldn't be symlinked from the repo — e.g. `yazi/.linkignore` excludes `.config/yazi/flavors/*` and `.config/yazi/plugins/*`, since those are managed at runtime by `ya pkg` instead.
- **Conflict handling** — if `link_package` finds a real file (not a symlink) already at the target path, it backs it up to `<target>.bak.<timestamp>` before linking over it.
- **`prune_stale_symlinks()`** runs before linking on every invocation: it sweeps `$HOME` (excluding `.cache`, `.cargo`, `.rustup`, `.npm`, `.local/share/nvim`, and the dotfiles repo itself) for any symlink pointing into the dotfiles repo whose target no longer exists, and removes it. This is how renamed/deleted config files stop leaving dangling links behind — `link_package` only ever creates/updates links for files that currently exist, it never notices ones that no longer have a source.
- **Flags:** `--update` (force re-download/rebuild everything), `--link` (skip binary downloads, just re-link configs), `--copy` (copy instead of symlink — useful on NTFS or shared servers), `--remove` (tear down all deployed symlinks and exit, binaries untouched), `--no-windows` (skip the WSL2 PowerShell steps), `--cargo` (build Rust tools from source instead of downloading prebuilt binaries — needed for `zjstatus-hints`, see above).

`install.sh` tracks installed binary/plugin versions in `~/.local/bin/.versions` (note: this is the **deployed** path under `$HOME`, not a file inside the repo — it's regenerated by `install.sh` and gitignored). On re-run it skips anything whose recorded version matches latest. `--update` forces everything to re-check.

When adding a new tool to `install.sh`, follow the existing `download_release()` pattern in the `CORE_TOOLS`/`CLI_TOOLS` arrays: `dest|crate|repo|os|arch|asset-glob|binary-name-in-archive`, fetched via the GitHub releases API and compared against `.versions`. Set `GITHUB_TOKEN` in your environment before a fresh install — unauthenticated GitHub API calls are capped at 60/hr, and installing 25+ tools from scratch can hit that.

---

## Deliberate omissions — do not add these

| What | Why not |
|---|---|
| **delta** | difftastic is the diff tool everywhere — `git diff`, lazygit, `GIT_EXTERNAL_DIFF`. No delta. |
| **top replacement** | `btm` (bottom) is a standalone addition, not a `top` alias. |
| **sed replacement** | `sd` is a standalone tool, not a `sed` alias. The syntax differs enough to break scripts. |
| **ping replacement** | `gping` is an additional visual tool. It does not replace `ping`. |
| **system package installs** | Everything goes to `~/.local/` — no `apt install` for user tools. Two narrow exceptions: `mosh` (no release binaries) and upgrading `git` itself via the git-core PPA on Ubuntu when it's older than 2.35 (needed for `zdiff3` merge style). |

---

## Alias priority chain

1. **Specialty Rust tools** — override their equivalent for specific commands (`bat`→`cat`, `fd`→`find`, `rg`→`grep`, `difft`→`diff`, `procs`→`ps`, `viddy`→`watch`, `tspin`→`tail`, `zoxide`→`cd`). Defined in `nushell/.config/nushell/autoload/aliases.nu`.
2. **`nr <tool>` function** — escape hatch to call the native system binary: `nr du -sh .` calls `/usr/bin/du`

The `nr` function is defined in `config.nu`:
```nushell
def nr [tool: string, ...args: string] {
    run-external $"/usr/bin/($tool)" ...$args
}
```

---

## WSL2-specific decisions

**Alacritty config symlink chain:** Alacritty runs natively on Windows and reads `%APPDATA%\alacritty\alacritty.toml`. `install.sh` creates an NTFS symlink from there into the WSL2 filesystem:

```
%APPDATA%\alacritty\alacritty.toml
  → \\wsl$\<distro>\home\<user>\.config\alacritty\alacritty.toml   (NTFS symlink, created by install.sh via powershell.exe)
    → ~/dotfiles/alacritty/.config/alacritty/alacritty.toml        (symlink, created by link_package)
```

Requires Windows Developer Mode. `install.sh` prints a manual fallback if symlink creation fails. The same PowerShell step (`windows-setup.ps1`) also installs Alacritty via winget and the JetBrainsMono Nerd Font — specifically the `JetBrainsMonoNerdFont*` files (NF/NFM/NFP), not the NL (no-ligature) variant.

**Clipboard:** Three layers keep everything in sync with the Windows clipboard:
- Zellij: `copy_on_select true` + `copy_clipboard "system"` — uses OSC52 via Alacritty (no `copy_command`; `clip.exe` by name is unreliable because Zellij doesn't inherit the shell PATH)
- Alacritty: `save_to_clipboard = true` — mouse selections auto-copy
- Neovim: `vim.opt.clipboard = "unnamedplus"` + `vim.g.clipboard` using `clip.exe` for copy, PowerShell for paste (defined in `autocmds.lua`)

**WSL2 detection in install.sh:** `grep -qi microsoft /proc/version` — the Windows-specific section (Alacritty install, font install, config symlink) only runs under WSL2. On native Linux/macOS, `install.sh` instead downloads the Nerd Font itself directly (see the "Fonts (Linux / macOS only)" section of the script).

---

## Theme

Catppuccin Mocha everywhere. Palette hex values are in:
- `alacritty/.config/alacritty/themes/catppuccin-mocha.toml` — committed (source of truth for terminal colors)
- `git/.gitconfig` — inline color values for git diff/status output
- `starship/.config/starship.toml` — full palette defined at the bottom of the file (`[palettes.catppuccin_mocha]`)
- `ripgrep/.config/ripgrep/ripgreprc` — match/line highlight colors
- `zellij/.config/zellij/config.kdl` — the `zjstatus` plugin block hardcodes the same hex values inline (no shared palette file with zjstatus)
- `zellij/.config/zellij/themes/catppuccin_m0rsla.kdl` — the Zellij UI theme itself (note: not the stock Catppuccin theme name — this is a locally-tweaked variant, referenced as `theme "catppuccin_m0rsla"` in `config.kdl`)
- Nushell theme sourced from `~/.config/nushell/themes/catppuccin_mocha.nu` (downloaded by install.sh, gitignored)

When adjusting colors, check all of the above — they don't share a single source.

---

## Plugin risk notes

Several small/young (or fork-dependent) plugins are load-bearing for navigation and the status bar:
- `fresh2dev/zellij-autolock` — switches Zellij to locked mode for nvim/hx/fzf/zoxide/atuin
- `swaits/zellij-nav.nvim` — Ctrl+hjkl in Neovim with Zellij edge-crossing
- `sudo-tee/opencode.nvim` — AI sidebar in Neovim (`<leader>ao`)
- `dj95/zjstatus` — status bar (mode/tab/system pills)
- `AlexZasorin/zellij-newtab-plus` — floating new-tab picker with zoxide
- `zjstatus-hints` — **highest risk of the group**: built from source off a *temporary community fork branch* (not upstream `main`), because upstream has no usable release. If the fork disappears or diverges further, the hints bar silently stops building — check `build_zjstatus_hints()` in `install.sh` for the current fork/branch and the TODO to revert once upstream catches up.

If any of these becomes unmaintained, the relevant config section will need replacing. They're small enough to fork if needed.
