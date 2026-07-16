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

`zellij/.config/zellij/layouts/default.kdl` renders a `zjstatus`-based status bar (mode pill, tab pills, weather/sysinfo/battery/claude-usage command pills, datetime, username/hostname) plus a `zjstatus-hints` keybinding-hints bar. Both are themed inline in `config.kdl`'s `plugins { zjstatus { ... } }` block with the Catppuccin Mocha hex palette — there is no shared palette file for zjstatus, so if the theme changes, update it here too (see [Theme](#theme)).

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
- **`homepath` git filter** (registered right after the `link_package` loop) — `zellij/.config/zellij/config.kdl`'s zjstatus `command_weather_command`/`command_sysinfo_command`/`command_battery_command`/`command_claudeusage_command`/`copy_command`, and `nvim/.config/nvim/lua/config/autocmds.lua`'s WSL clipboard `copy` entry, all need real absolute paths to the scripts in `zellij/.config/zellij/scripts/` — zjstatus's WASM plugin execs commands directly (no shell, no `~`/`$HOME` expansion) and Neovim's `g.clipboard` exec is likewise not shell-expanded. These two files are symlinked (not copied) straight into `$HOME`, so a naive absolute path would carry whichever machine's username last edited them. Instead, the files in git store a `__DOTFILES_HOME__` placeholder, and `.gitattributes` marks both with `filter=homepath`: `git-filters/homepath-smudge.sh` expands the placeholder to the real `$HOME` on checkout (so the deployed file works), and `git-filters/homepath-clean.sh` folds it back to the placeholder before anything is staged (so `git add`/`git commit` from any machine never stages a machine-specific path — no more manually excluding those hunks when committing from a different box). Filter *commands* are local git config, not versioned, so `install.sh` re-registers them (`git config filter.homepath.*`) and force-checks-out both files on every run, in case the filter wasn't registered yet the last time they were written to the working tree (e.g. right after a fresh clone). Two subtle failure modes bit this in practice, so `install.sh` now guards both: (1) `git-filters/homepath-*.sh` must themselves stay executable in git (git execs them directly, no `sh -c` wrapper — same pitfall as the five scripts below), so `install.sh` `chmod +x`s them defensively before registering the filter; (2) `git checkout-index -f` only forces *overwriting*, it does not bypass git's stat-based freshness check, so if the working-tree file's mtime already matches the index (e.g. it was checked out once before the filter existed) it silently skips re-smudging with no error — `install.sh` now `rm`s both files immediately before the `checkout-index -f` call to force a real rewrite, then greps both for a leftover `__DOTFILES_HOME__` and fails loudly if the filter didn't actually run.
- The five scripts in `zellij/.config/zellij/scripts/` (`weather.py`, `sysinfo.py`, `battery.py`, `claude-usage.py`, `clip-clean.py`) must stay executable in git (`chmod +x` + committed) — they're invoked directly (no `sh -c` wrapper) by both zjstatus and Neovim's clipboard provider, so a non-executable mode bit fails silently as `Permission denied` from the caller's perspective (copy/pills just stop working, no visible error in the terminal).

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

Requires Windows Developer Mode. `install.sh` prints a manual fallback if symlink creation fails (and `windows-setup.ps1` itself falls back to `Copy-Item` when the symlink call throws — without Developer Mode this makes the config a plain copy, so it re-copies from source on every `install.sh` run instead of staying live-linked). The same PowerShell step (`windows-setup.ps1`) also installs Alacritty via winget and the JetBrainsMono Nerd Font — specifically the `JetBrainsMonoNerdFont*` files (NF/NFM/NFP), not the NL (no-ligature) variant.

**Clipboard:** Three layers keep everything in sync with the Windows clipboard, and both Zellij and Neovim route copies through `zellij/.config/zellij/scripts/clip-clean.py` (not `clip.exe` directly) so Nerd Font glyphs in yanked/copied text (branch icons, status pills) don't turn into tofu boxes when pasted somewhere without the font:
- Zellij: `copy_on_select true` + `copy_command "<clip-clean.py path>"` (`copy_clipboard "system"` is kept in `config.kdl` as an inert fallback — unused while `copy_command` is set)
- Alacritty: `save_to_clipboard = true` — mouse selections auto-copy
- Neovim: `vim.opt.clipboard = "unnamedplus"` + `vim.g.clipboard.copy` pointing at the same `clip-clean.py`, paste via PowerShell `Get-Clipboard` (defined in `autocmds.lua`)

`clip-clean.py` (and the zjstatus `weather.py`/`sysinfo.py`/`battery.py`/`claude-usage.py` scripts alongside it) must be executable in git — see the `homepath` git filter note above for both the exec-bit and the hardcoded-absolute-path pitfalls, since both fail silently (copy/pills just stop working, no terminal error).

**WSL2 detection in install.sh:** `grep -qi microsoft /proc/version` — the Windows-specific section (Alacritty install, font install, config symlink) only runs under WSL2. On native Linux/macOS, `install.sh` instead downloads the Nerd Font itself directly (see the "Fonts (Linux / macOS only)" section of the script).

**WSL distro name detection:** `install.sh` reads `$WSL_DISTRO_NAME` (set by WSL itself for the current session) to build the `\\wsl.localhost\<distro>\...` path used for the Alacritty symlink/copy target. It falls back to `wsl.exe --list --running --quiet | head -1` only if that's unset — that fallback is unreliable if more than one distro is registered/running (e.g. a leftover install alongside the current one), since list ordering isn't guaranteed to put the current distro first, which silently points the Alacritty config at a nonexistent path and leaves `%APPDATA%\alacritty\alacritty.toml` missing (breaking `Ctrl+C`/OSC52 copy in the shell) with no obvious error.

---

## Neovim (LazyVim) layout

The Neovim config is LazyVim-based; **keep changes idiomatic** — reach for an official LazyVim extra or a standard spec pattern before hand-rolling. Inspect `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/` to find one. The design splits responsibilities: **Zellij is the chrome (tabs, status bar, panes), Neovim is the editor.**

- **File sidebar:** Snacks explorer via the official `snacks_explorer` extra (imported in `lua/config/lazy.lua`), bound to `<leader>e`. `plugins/snacks.lua` sets `picker.sources.explorer.hidden = true` — **required**, because this repo is almost entirely dot-directories (`.config`/`.local`) and dotfiles; without it most package folders expand to nothing. `ignored` stays off so downloaded binaries under `bin/.local/` don't flood the tree (`H`/`I` toggle hidden/ignored at runtime).
- **Status bar:** lualine is **disabled** (`plugins/lualine.lua`, `enabled=false`) with `laststatus=0` (in `config/options.lua`), because the Zellij zjstatus bar already renders mode/git/clock/system — a bottom statusline would just duplicate it. Per-window info comes from `incline.nvim` (`plugins/incline.lua`) — a floating top-right label showing *file info* (filetype · line count · size · indent, plus diagnostics and git-diff counts and a modified/read-only marker). It does **not** repeat the filename, because dropbar's winbar already shows it (see "Location in file" below).
- **AI sidebar:** `coder/claudecode.nvim` (`plugins/claudecode.lua`, `<leader>a…`, toggle `<leader>ac`) speaks the same MCP/WebSocket protocol as the VSCode extension. It replaced the earlier `sudo-tee/opencode.nvim` (user wants Claude Code only). `claude` is on `$PATH` (`~/.local/bin/claude`), so no `terminal_cmd` override.
- **Terminal:** snacks terminal docked bottom (`<c-/>`). The Nushell `zellij_autostart` guard (`config.nu`) also checks `$NVIM`, so a terminal opened *inside* Neovim never spawns a nested Zellij session.
- **Location in file:** `dropbar.nvim` (`plugins/dropbar.lua`) renders VSCode-style breadcrumbs (`folder › file › Symbol`) in each window's winbar, top-left; its symbol source falls back to treesitter, so it works without an LSP. Sticky scroll is the `ui.treesitter-context` extra — it pins the enclosing scope (fn/class/loop) to the top as you scroll. Together with incline's file info, these cover what a lualine statusline/winbar used to show.
- **Language support:** enabled via LazyVim `lang.*` extras where they exist — `lang.rust` (rust-analyzer), `lang.python` (pinned to **pyright** via `vim.g.lazyvim_python_lsp` in `options.lua`, *not* basedpyright — basedpyright installs via pip and there is none here), `lang.php` (intelephense, a pure-Node analyzer, so no PHP runtime needed). HTML/CSS/Emmet/Bash have no lang extras, so their servers are declared in `plugins/lsp-servers.lua`. Those are all Node/npm packages installed by Mason — which is why `install.sh` installs a Linux **Node.js into `~/.local`** (the Windows `npm` leaking onto PATH via WSL interop would install unusable Windows binaries; `env.nu` prepends `~/.local/bin` so the Linux one wins). **ruff** is the exception — pip-based in Mason — so `install.sh` installs it as a standalone binary and `plugins/lsp-servers.lua` sets `ruff = { mason = false }` so Mason doesn't try. Treesitter parsers for all seven languages live in `plugins/treesitter.lua`, so highlighting works even where an LSP can't be installed. **PowerShell** (`powershell_es`) runs on `pwsh`, which `install.sh` installs as a self-contained tarball into `~/.local/lib/powershell` (symlinked to `~/.local/bin/pwsh`) — it bundles its own .NET runtime, so no separate .NET/root is needed; Mason supplies the PowerShell Editor Services bundle.
- **`lazy-lock.json` is gitignored** — nvim plugin versions are deliberately not pinned across machines the way `install.sh`'s `.versions` are. If a `Lazy sync` errors writing it, check the file isn't root-owned (`chown` back to your user).

Load-bearing must-keeps: the catppuccin theme and the Ctrl+hjkl Zellij navigation (see [Unified Ctrl+hjkl navigation](#unified-ctrlhjkl-navigation)).

---

## Claude Code integration

**Usage pill** (`zellij/.config/zellij/scripts/claude-usage.py`, wired into `config.kdl` exactly like the weather/sysinfo/battery pills): shows current 5-hour billing-block usage + its reset time, current-week usage, and all-time total tokens. Sourced from `ccusage` (`install_ccusage()` in `install.sh`, version-**pinned** rather than always-latest like the GitHub-release `CLI_TOOLS` — the script parses `ccusage`'s `--json` output directly, so an unreviewed bump could silently break it with no visible error; bump deliberately and re-check the output shape). **This is a local-log-derived estimate**, not a live read of Anthropic's account: `ccusage` reconstructs the 5-hour/weekly rolling windows by parsing local `~/.claude/projects/*/*.jsonl` session logs — there's no public API for actual account-level rate-limit consumption, so the numbers approximate but won't be pixel-perfect against claude.ai. The script always calls the pinned local binary with `--offline` (never `npx ccusage@latest`), since it's polled every 60s and must never depend on the network or npm registry.

**`claude` package** (in `PACKAGES`): symlinks `~/.claude/settings.json` from `claude/.claude/settings.json`, so the Notification hook below (and `theme`) are version-controlled across machines. `claude/.claude/CLAUDE.md` — a generic pair-programming prompt left over from the initial repo import, never reviewed as real global instructions — is deliberately excluded from deployment via `claude/.linkignore`; delete that line once it's been reviewed and you actually want it live.

**Idle/permission notifications**: `claude/.claude/settings.json` registers `claude/.claude/scripts/claude-notify.py` as the `Notification` hook with **no matcher** (catch-all — Claude Code's docs were inconsistent on whether `Notification` reliably supports matcher-based filtering, so filtering happens in the script instead). The script checks the hook's `notification_type` field against a `NOTIFY_TYPES` constant at the top of the file (`{"idle_prompt", "permission_prompt"}` by default) — edit that one line to change which notification types surface. Matches are forwarded into zjstatus's existing notification pill via `zellij pipe "zjstatus::notify::<message>"` (zjstatus's own pipe protocol — no `config.kdl` changes needed, `format_center "{notifications}"` already renders it). Side-effect only, per Claude Code's hook docs (`Notification` has no decision control): the script always exits 0 and swallows every failure (missing `zellij`, not inside a session, malformed payload) so it can never block or error a Claude Code session.

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
- `coder/claudecode.nvim` — Claude Code AI sidebar in Neovim (`<leader>a…`, toggle `<leader>ac`)
- `dj95/zjstatus` — status bar (mode/tab/system pills)
- `AlexZasorin/zellij-newtab-plus` — floating new-tab picker with zoxide
- `zjstatus-hints` — **highest risk of the group**: built from source off a *temporary community fork branch* (not upstream `main`), because upstream has no usable release. If the fork disappears or diverges further, the hints bar silently stops building — check `build_zjstatus_hints()` in `install.sh` for the current fork/branch and the TODO to revert once upstream catches up.

If any of these becomes unmaintained, the relevant config section will need replacing. They're small enough to fork if needed.
