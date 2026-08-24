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

Plugins currently pinned this way: `zellij-autolock` (fresh2dev, tag-based release), `zjstatus` (dj95, tag-based release), `zellij-newtab-plus` (AlexZasorin, tag-based release, powers the `c` new-tab binding above), `zjstatus-hints` (**our own fork**, `myah-mitchell/zjstatus-hints`, tag-based release — upstream `b0o/zjstatus-hints` has no usable release, so rather than building from source we publish tagged releases from our fork and pin those like any other plugin here).

**Plugin permission pre-seeding:** each plugin's `request_permission()` call needs one-time interactive y/n approval, rendered in its own pane. Since `zjstatus`/`zellij-autolock` live in unfocused size-1 borderless panes, that prompt is easy to never see — the plugin then silently sits inert. `install.sh` pre-writes grants to `~/.cache/zellij/permissions.kdl` (append-only — never clobbers grants for other plugins) so this never blocks a fresh install. If you bump a plugin version and it starts requesting new permission scopes, update the matching entry in `ZELLIJ_PLUGIN_PERMISSIONS` in `install.sh`.

---

## Zsh: .zshenv vs .zshrc

The primary shell is zsh (migrated from Nushell — Nu's structured-data model broke too many bash-oriented guides/scripts; the last Nu-based commit is tagged `pre-zsh-migration`). Config lives in the `zsh` package, laid out plainly under `$HOME` (mirroring the existing `bash` package's pattern, not the XDG-nested `~/.config/nushell` layout Nu used — zsh's own `.zshenv`/`.zshrc` bootstrap files have no equivalent of Nu's built-in `$XDG_CONFIG_HOME` awareness, and relocating them via `ZDOTDIR` requires a fragile chicken-and-egg bootstrap trick not worth the complexity here):

- **`zsh/.zshenv`** → `~/.zshenv` — environment variables only. Sourced on *every* zsh invocation (interactive, scripts, non-interactive), not just login shells.
- **`zsh/.zshrc`** → `~/.zshrc` — everything else: history/completion options, tool-init sourcing, the `zellij_autostart` function, `y`/`sudo` wrapper functions, keybindings, plugin loading. Aliases live separately in `zsh/.config/zsh/aliases.zsh`, sourced explicitly from `.zshrc` (pure organizational convention here — unlike Nu's autoload directory, zsh doesn't require aliases to live anywhere specific).

**Tool-init sourcing** — no parse-time restriction to work around (zsh's `source` is a runtime call, unlike Nu's parse-time-only `source`), but the pattern of sourcing from fixed generated paths is kept anyway, for the same reason the Zellij plugins are pinned to local files: these get sourced on every new shell via `zellij_autostart`, so a live/dynamic lookup would add latency to every terminal, not just the first one.

```
~/.local/share/atuin/init.zsh      ← generated by: atuin init zsh --disable-up-arrow
~/.local/share/zoxide/init.zsh     ← generated by: zoxide init zsh
~/.cache/starship/init.zsh         ← generated by: starship init zsh
~/.cache/carapace/init.zsh         ← generated by: carapace _carapace zsh
```

If you need to add another tool that generates a shell init script, follow this same pattern.

**History:** `.zshrc` sets `HISTFILE`/`HISTSIZE`/`SAVEHIST` plus `setopt SHARE_HISTORY INC_APPEND_HISTORY` — this is just zsh's own plain backing store; atuin still owns the actual searchable/fuzzy history (bound to `Ctrl+R` by its own init script) the same way it did under Nu. Nu's `isolation: true` setting (each shell session only seeing its own history entries) has no direct zsh equivalent and wasn't ported — if per-session isolation is ever needed again, it'd have to be layered on via atuin's own session filtering rather than a shell-level setting.

**Plugins** (`zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-you-should-use`) — deliberately not a framework like oh-my-zsh: Starship/atuin/zoxide/carapace already own prompt/history/completion, so a framework would only add redundant theme/plugin machinery. Instead these three are pinned and downloaded the same way as the `ZELLIJ_PLUGINS` (see above) — the `ZSH_PLUGINS` array in `install.sh`, versions tracked in `.versions`. One difference from the Zellij plugins: none of these publish GitHub Releases (no binary asset, just tagged source), so instead of downloading one release asset, `install.sh` downloads the full source tarball at a pinned tag (`github.com/<repo>/archive/refs/tags/<tag>.tar.gz`) and extracts it whole into `~/.local/share/zsh/plugins/<name>/` — `.zshrc` sources each plugin's `.plugin.zsh` entrypoint from that fixed path. Load order matters: `zsh-syntax-highlighting` must be sourced **last**, after anything else that wraps zle widgets, or it breaks other plugins' keybindings. Both highlighting plugins are Catppuccin Mocha-colored — `zsh-syntax-highlighting` via the downloaded theme described below; `zsh-autosuggestions` via a manually set `ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE` (no official catppuccin port exists for it).

**Dropped in the migration, not ported:** Nu's `nr <tool>` escape-hatch function (zsh's builtin `command <tool>` / `\<tool>` already bypasses an alias, no wrapper needed) and the custom `sudo!!` function (zsh's native `!!` history expansion means `sudo !!` already works). The `sudo` PATH-reinjection wrapper *was* kept — sudo's `secure_path` (in `/etc/sudoers`) strips `PATH` regardless of shell, so `sudo bat`/`sudo rg` still need it to find `~/.local/bin` tools.

---

## Config deployment: hand-rolled linker

`install.sh` deploys configs with its own `link_package()`/`remove_package()`/`prune_stale_symlinks()` functions, which walk each package directory and symlink (or, with `--copy`, copy) every file into the matching path under `$HOME`, one file at a time.

```
~/.local/bin/bat  →  ~/dotfiles/bin/.local/bin/bat   (symlink created by link_package)
                               ↑
                      actual binary (gitignored, downloaded by install.sh)
```

Key behaviors specific to this hand-rolled linker:
- **`PACKAGES` array** in `install.sh` lists the top-level package dirs: `bin bash zsh starship zellij nvim git ripgrep bat yazi atuin lazygit tealdeer ssh alacritty`. Adding a new package means adding its directory name here.
- **`.linkignore`** — a package can drop a `.linkignore` file in its root (glob per line, `#` comments) to exclude files that shouldn't be symlinked from the repo — e.g. `yazi/.linkignore` excludes `.config/yazi/flavors/*` and `.config/yazi/plugins/*`, since those are managed at runtime by `ya pkg` instead.
- **Conflict handling** — if `link_package` finds a real file (not a symlink) already at the target path, it backs it up to `<target>.bak.<timestamp>` before linking over it.
- **`prune_stale_symlinks()`** runs before linking on every invocation: it sweeps `$HOME` (excluding `.cache`, `.cargo`, `.rustup`, `.npm`, `.local/share/nvim`, and the dotfiles repo itself) for any symlink pointing into the dotfiles repo whose target no longer exists, and removes it. This is how renamed/deleted config files stop leaving dangling links behind — `link_package` only ever creates/updates links for files that currently exist, it never notices ones that no longer have a source.
- **Flags:** `--update` (force re-download/rebuild everything), `--link` (skip binary downloads, just re-link configs), `--copy` (copy instead of symlink — useful on NTFS or shared servers), `--remove` (tear down all deployed symlinks and exit, binaries untouched), `--no-windows` (skip the WSL2 PowerShell steps), `--cargo` (build Rust tools from source instead of downloading a prebuilt release — slow and disk-heavy), `--claude` (install the Claude Code stack — see below), `--full` (implies `--claude`; also installs `install_powershell()` and enables nvim's heavier Mason LSPs — see below), `--cleanup` (remove orphaned/stale local state — see below). The `rustup`/cargo bootstrap itself is gated on `--cargo` (not run otherwise) — before the Nushell→zsh migration it ran unconditionally because a couple of Nu plugins shipped no prebuilt binary at all and needed cargo regardless of the flag; with Nu gone, nothing needs cargo unless `--cargo` is explicitly requested.
- **`--claude` / `--full`** — both opt-**in** (every other flag opts something *out* of a default-on install). `WANT_CLAUDE_STACK` (computed once, right after arg parsing, as `--claude || --full`) gates `install_claude()` (the Claude Code CLI itself, via the native `curl -fsSL https://claude.ai/install.sh | bash` installer — see Claude Code integration below), `install_node()`, `install_ccstatusline()`, and `install_claude_swap()` — none of the latter three are useful without Claude Code, so none of them install unless this run wants the stack. `--full` implies `--claude` (a full IDE workstation still wants Claude Code) and additionally gates two things `--claude` alone does not: (1) installing PowerShell (`pwsh`, a ~190MB self-contained tarball, needed only by the `powershell_es` LSP), and (2) whether `nvim` enables its heavier Mason-managed LSP servers at all — `html`/`cssls`/`emmet_language_server`/`bashls`/`pyright` and the whole `lang.php` extra (`intelephense`/`phpactor`/`php-cs-fixer`/`phpcs`) — together ~460MB of Mason packages that only make sense on a full IDE workstation. Since `--full` implies `WANT_CLAUDE_STACK`, Node is still installed whenever those LSPs need it — the "is node on PATH" nvim signal problem this created is unchanged from before: it can't serve as nvim's `--full` signal (it'd read true under `--claude` alone too) — see the marker-file mechanism in the Neovim section below. `powershell_es` doesn't need that marker, though: nothing but `--full` installs `pwsh`, so `nvim` checks `vim.fn.executable("pwsh")` directly. Pass `--full` on a full Neovim IDE workstation, `--claude` alone on a machine that just wants Claude Code without the IDE extras, and leave both off on servers/shared boxes that only need the shell environment — that's the default.
- **`--cleanup`** — `install.sh`'s downloaders are all overwrite-in-place (a `CORE_TOOLS`/`CLI_TOOLS` entry, a Zellij plugin, a zsh plugin all get re-downloaded onto the same fixed path), which means nothing ever notices when a tool is *removed* from those arrays entirely — its old binary just sits on disk forever with a stale `.versions` entry. `cleanup_orphans()` (defined near the end of `install.sh`, run when `--cleanup` is passed) diffs `.versions` against the exact `CORE_TOOLS`/`CLI_TOOLS`/`ZELLIJ_PLUGINS`/`ZSH_PLUGINS` arrays used to install things — plus a short static list for the handful of bespoke installers that don't use those arrays (`nvim`, `yazi`, `jetbrainsmono-nf` always known; `node`/`ccstatusline` known only when `WANT_CLAUDE_STACK`; `pwsh` known only when `--full`) — and removes anything left over: `$BIN_DIR` binaries, Zellij `.wasm` files, zsh plugin dirs, and orphaned `npm install -g` packages (checked against `~/.local/lib/node_modules/<key>` — this is what actually uninstalls `ccstatusline` when it's orphaned). **`node` is the one deliberate exception**: when orphaned it's left in place with a warning rather than auto-removed, because `install_node()`'s `cp -a` merges node's own `bin`/`lib`/`include`/`share` trees straight into the same `~/.local/{bin,lib,...}` directories that real dotfiles-deployed symlinks and other npm globals live in — unlike `pwsh`'s isolated `~/.local/lib/powershell`, there's no single path that's safely `rm -rf`-able as "node and nothing else," so guessing wrong risks deleting files this script doesn't own. It also removes `~/.rustup`/`~/.cargo` outright when the run isn't `--cargo` (regenerated on demand by the next `--cargo` run), and — when the run isn't `--full` — uninstalls the fixed list of full-only Mason LSP packages (same list as the `--full` bullet above) via a headless `nvim --headless -c "MasonUninstall ..."` if any are present, since Neovim's Mason downloads aren't installed by `install.sh` at all and so can't be caught by the `.versions` diff. No effect combined with `--link` (those arrays are never populated without a real run — `install.sh` warns and skips rather than risk misjudging orphans off an empty set). Separately (not part of the `.versions` diff, since `install.sh`'s own tracking doesn't cover `claude` — see below), `cleanup_orphans()` also removes old Claude Code version binaries, *regardless* of `WANT_CLAUDE_STACK`: the native installer/self-updater drops each new version into `~/.local/share/claude/versions/<version>` (~300-350MB apiece) and repoints the `~/.local/bin/claude` symlink at it, but never deletes the old ones — `cleanup_orphans()` resolves that symlink and removes every sibling in `versions/` that isn't the current target, whether or not this run also passed `--claude`. **When adding a new bespoke installer that doesn't go through `CORE_TOOLS`/`CLI_TOOLS`/`ZELLIJ_PLUGINS`/`ZSH_PLUGINS`, add its key to `cleanup_orphans()`'s static `known_dest` list too** — this was tested against live orphaned state on the maintainer's machine before landing, and testing caught exactly this gap once already (`yazi` uses `download_release()` directly, bypassing `CLI_TOOLS`, and got wrongly deleted as a false orphan in the first pass — fixed by adding it to the static list; `ya`, yazi's companion binary, was confirmed to never get a `.versions` entry at all, so it needed no such fix).
- **`homepath` git filter** (registered right after the `link_package` loop) — `zellij/.config/zellij/config.kdl`'s zjstatus `command_weather_command`/`command_sysinfo_command`/`command_battery_command`/`copy_command` need real absolute paths to the scripts in `zellij/.config/zellij/scripts/`: zjstatus's WASM plugin execs commands directly (confirmed in its `src/widgets/command.rs` — the config string is split into argv and handed straight to `run_command`, no shell, no `~`/`$HOME` expansion of any kind) and this has nothing to do with which shell the user runs interactively, since zjstatus never invokes one either way. `config.kdl` is symlinked (not copied) straight into `$HOME`, so a naive absolute path would carry whichever machine's username last edited it. Instead, the file in git stores a `__DOTFILES_HOME__` placeholder, and `.gitattributes` marks it `filter=homepath`: `git-filters/homepath-smudge.sh` expands the placeholder to the real `$HOME` on checkout (so the deployed file works), and `git-filters/homepath-clean.sh` folds it back to the placeholder before anything is staged (so `git add`/`git commit` from any machine never stages a machine-specific path — no more manually excluding those hunks when committing from a different box). Filter *commands* are local git config, not versioned, so `install.sh` re-registers them (`git config filter.homepath.*`) and force-checks-out the file on every run, in case the filter wasn't registered yet the last time it was written to the working tree (e.g. right after a fresh clone). Two subtle failure modes bit this in practice, so `install.sh` now guards both: (1) `git-filters/homepath-*.sh` must themselves stay executable in git (git execs them directly, no `sh -c` wrapper — same pitfall as the five scripts below), so `install.sh` `chmod +x`s them defensively before registering the filter; (2) `git checkout-index -f` only forces *overwriting*, it does not bypass git's stat-based freshness check, so if the working-tree file's mtime already matches the index (e.g. it was checked out once before the filter existed) it silently skips re-smudging with no error — `install.sh` now `rm`s the file immediately before the `checkout-index -f` call to force a real rewrite, then greps for a leftover `__DOTFILES_HOME__` and fails loudly if the filter didn't actually run. **Neovim's equivalent problem doesn't need this filter**: `nvim/.config/nvim/lua/config/autocmds.lua`'s WSL clipboard `copy` entry has the exact same "no shell expansion" constraint (confirmed the same way), but unlike static KDL data, that file is Lua — evaluated by nvim itself on whatever machine it's running on — so it just computes the path with `vim.fn.expand("~/.config/zellij/scripts/clip-clean.py")` at load time instead of baking one in. No placeholder, no filter, no `install.sh` involvement needed for that file at all. If a future file has this same problem, check whether it's *executable config* (can compute its own path — do that) before reaching for this filter (only for genuinely static data a non-shell-invoking consumer reads as-is).
- The four scripts in `zellij/.config/zellij/scripts/` (`weather.py`, `sysinfo.py`, `battery.py`, `clip-clean.py`) must stay executable in git (`chmod +x` + committed) — they're invoked directly (no `sh -c` wrapper) by both zjstatus and Neovim's clipboard provider, so a non-executable mode bit fails silently as `Permission denied` from the caller's perspective (copy/pills just stop working, no visible error in the terminal).

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
| **system package installs** | Everything goes to `~/.local/` — no `apt install` for user tools. Two narrow exceptions: `mosh` (no release binaries) and upgrading `git` itself via the git-core PPA on Ubuntu when it's older than 2.35 (needed for `zdiff3` merge style). zsh itself is a deliberate *non*-exception: it has no cross-platform prebuilt release binary either, but rather than adding a third `apt install` exception, `install.sh` requires it pre-installed and errors with instructions if it's missing. |

---

## Alias priority chain

1. **Specialty Rust tools** — override their equivalent for specific commands (`bat`→`cat`, `fd`→`find`, `rg`→`grep`, `difft`→`diff`, `procs`→`ps`, `viddy`→`watch`, `tspin`→`tail`, `zoxide`→`cd`, `eza`→`ls`). Defined in `zsh/.config/zsh/aliases.zsh`.
2. **`command <tool>` / `\<tool>`** — zsh's builtin escape hatch to call the native system binary, bypassing an alias: `command du -sh .` calls `/usr/bin/du`. (Nu had no equivalent builtin, hence the old `nr` wrapper function — dropped in the zsh migration since it's no longer needed.)

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

`clip-clean.py` (and the zjstatus `weather.py`/`sysinfo.py`/`battery.py` scripts alongside it) must be executable in git — see the `homepath` git filter note above for both the exec-bit and the hardcoded-absolute-path pitfalls, since both fail silently (copy/pills just stop working, no terminal error).

**WSL2 detection in install.sh:** `grep -qi microsoft /proc/version` — the Windows-specific section (Alacritty install, font install, config symlink) only runs under WSL2. On native Linux/macOS, `install.sh` instead downloads the Nerd Font itself directly (see the "Fonts (Linux / macOS only)" section of the script).

**WSL distro name detection:** `install.sh` reads `$WSL_DISTRO_NAME` (set by WSL itself for the current session) to build the `\\wsl.localhost\<distro>\...` path used for the Alacritty symlink/copy target. It falls back to `wsl.exe --list --running --quiet | head -1` only if that's unset — that fallback is unreliable if more than one distro is registered/running (e.g. a leftover install alongside the current one), since list ordering isn't guaranteed to put the current distro first, which silently points the Alacritty config at a nonexistent path and leaves `%APPDATA%\alacritty\alacritty.toml` missing (breaking `Ctrl+C`/OSC52 copy in the shell) with no obvious error.

---

## Neovim (LazyVim) layout

The Neovim config is LazyVim-based; **keep changes idiomatic** — reach for an official LazyVim extra or a standard spec pattern before hand-rolling. Inspect `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/` to find one. The design splits responsibilities: **Zellij is the chrome (tabs, status bar, panes), Neovim is the editor.**

- **File sidebar:** Snacks explorer via the official `snacks_explorer` extra (imported in `lua/config/lazy.lua`), bound to `<leader>e`. `plugins/snacks.lua` sets `picker.sources.explorer.hidden = true` — **required**, because this repo is almost entirely dot-directories (`.config`/`.local`) and dotfiles; without it most package folders expand to nothing. `ignored` stays off so downloaded binaries under `bin/.local/` don't flood the tree (`H`/`I` toggle hidden/ignored at runtime).
- **Status bar:** lualine is **disabled** (`plugins/lualine.lua`, `enabled=false`) with `laststatus=0` (in `config/options.lua`), because the Zellij zjstatus bar already renders mode/git/clock/system — a bottom statusline would just duplicate it. Per-window info comes from `incline.nvim` (`plugins/incline.lua`) — a floating top-right label showing *file info* (filetype · line count · size · indent, plus diagnostics and git-diff counts and a modified/read-only marker). It does **not** repeat the filename, because dropbar's winbar already shows it (see "Location in file" below).
- **AI sidebar:** `coder/claudecode.nvim` (`plugins/claudecode.lua`, `<leader>a…`, toggle `<leader>ac`) speaks the same MCP/WebSocket protocol as the VSCode extension. It replaced the earlier `sudo-tee/opencode.nvim` (user wants Claude Code only). `claude` is on `$PATH` (`~/.local/bin/claude`), so no `terminal_cmd` override.
- **Terminal:** snacks terminal docked bottom (`<c-/>`). The zsh `zellij_autostart` function (`.zshrc`) also checks `$NVIM`, so a terminal opened *inside* Neovim never spawns a nested Zellij session.
- **Location in file:** `dropbar.nvim` (`plugins/dropbar.lua`) renders VSCode-style breadcrumbs (`folder › file › Symbol`) in each window's winbar, top-left; its symbol source falls back to treesitter, so it works without an LSP. Sticky scroll is the `ui.treesitter-context` extra — it pins the enclosing scope (fn/class/loop) to the top as you scroll. Together with incline's file info, these cover what a lualine statusline/winbar used to show.
- **Language support:** enabled via LazyVim `lang.*` extras where they exist — `lang.rust` (rust-analyzer, no Node dependency, always on), `lang.python` (pinned to **pyright** via `vim.g.lazyvim_python_lsp` in `options.lua`, *not* basedpyright — basedpyright installs via pip and there is none here), `lang.php` (intelephense, a pure-Node analyzer, so no PHP runtime needed). HTML/CSS/Emmet/Bash have no lang extras, so their servers are declared in `plugins/lsp-servers.lua`. Those, plus `pyright` and the whole `lang.php` extra, are all Node/npm packages installed by Mason — which is why `install.sh` installs a Linux **Node.js into `~/.local`** unconditionally (the Windows `npm` leaking onto PATH via WSL interop would install unusable Windows binaries; `zsh/.zshenv` prepends `~/.local/bin` so the Linux one wins). **ruff** is the exception — pip-based in Mason — so `install.sh` installs it as a standalone binary and `plugins/lsp-servers.lua` sets `ruff = { mason = false }` so Mason doesn't try; ruff is always on, no Node/pwsh dependency. Treesitter parsers for all seven languages live in `plugins/treesitter.lua`, so highlighting works even where an LSP can't be installed. **PowerShell** (`powershell_es`) runs on `pwsh`, which `install.sh --full` installs as a self-contained tarball into `~/.local/lib/powershell` (symlinked to `~/.local/bin/pwsh`) — it bundles its own .NET runtime, so no separate .NET/root is needed; Mason supplies the PowerShell Editor Services bundle.
- **`--full`-gated LSPs (Mason disk footprint):** `html`/`cssls`/`emmet_language_server`/`bashls`/`pyright` and the `lang.php` extra are ~460MB combined once Mason downloads them, so they're only enabled on a full IDE workstation. `config/lazy.lua` reads `~/.local/state/dotfiles/full-install` (a marker file `install.sh` writes/removes every run based on `--full`) to decide whether to `table.insert` the `lang.php` extra into its plugin spec at all; `plugins/lsp-servers.lua` reads the same marker to decide whether to declare `html`/`cssls`/`emmet_language_server`/`bashls`, and sets `servers.pyright = false` outside `--full` to override `lang.python`'s own unconditional pyright config (LazyVim's documented idiom for opting a server out of Mason auto-install — `false` gets normalized to `{ enabled = false }` in `lazyvim.plugins.lsp.init`, which both skips `vim.lsp.enable()` and excludes it from `mason-lspconfig`'s `ensure_installed`). The marker exists because Node.js is gated behind `WANT_CLAUDE_STACK` (`--claude` *or* `--full`, not `--full` alone — see above), so nvim can't just check `vim.fn.executable("node")` the way it checks `vim.fn.executable("pwsh")` for `powershell_es`: that would read true under `--claude` alone too, without `--full` having been passed. Toggling `--full` on install.sh reconfigures what nvim *would* enable on next launch, but does **not** retroactively uninstall whatever Mason already downloaded under the old setting — that's a manual `:Mason` / `:MasonUninstall <package>` cleanup step. `lang.markdown`'s Node tooling (marksman/markdownlint-cli2/markdown-toc/prettier, ~30MB) is deliberately left ungated — small enough, and common enough to want on any machine, not to bother tying to `--full`.
- **`lazy-lock.json` is gitignored** — nvim plugin versions are deliberately not pinned across machines the way `install.sh`'s `.versions` are. If a `Lazy sync` errors writing it, check the file isn't root-owned (`chown` back to your user).

Load-bearing must-keeps: the catppuccin theme and the Ctrl+hjkl Zellij navigation (see [Unified Ctrl+hjkl navigation](#unified-ctrlhjkl-navigation)).

---

## Claude Code integration

**The `claude` CLI itself**: installed by `install_claude()` in `install.sh`, gated behind `--claude`/`--full` (`WANT_CLAUDE_STACK` — see the Flags section above) like the rest of this stack. Uses the official native installer (`curl -fsSL https://claude.ai/install.sh | bash`), which manages its own launcher at `~/.local/bin/claude` — a symlink into `~/.local/share/claude/versions/<version>` — and self-updates in the background on its own, independent of `install.sh`. Because of that, `install_claude()` doesn't track a version in `.versions` the way other tools do; there's nothing meaningful to compare against. `--update` runs `claude update` to force an immediate check instead of waiting for the background updater. `install.sh --cleanup` separately prunes old version dirs the native updater leaves behind under `~/.local/share/claude/versions/` (see the `--cleanup` bullet above) — that part runs regardless of `WANT_CLAUDE_STACK`, since cleaning up an already-installed Claude Code's stale versions doesn't depend on whether this run also wants it (re)installed.

**`claude` package** (in `PACKAGES`, unconditional — always deployed regardless of `WANT_CLAUDE_STACK`, since it's just a config symlink, not a download): symlinks `~/.claude/settings.json` from `claude/.claude/settings.json`, so the Notification hook below (and `theme`) are version-controlled across machines. `claude/.claude/CLAUDE.md` — a generic pair-programming prompt left over from the initial repo import, never reviewed as real global instructions — is deliberately excluded from deployment via `claude/.linkignore`; delete that line once it's been reviewed and you actually want it live.

**Status line** (`sirmalloc/ccstatusline`, npm package): renders the per-message status line inside the Claude Code TUI itself (model, thinking effort, git branch/changes, context-window usage, compaction counter, 5-hour/weekly reset timers, token breakdown) — lives inside Claude Code itself, distinct from the zjstatus pills in the Zellij chrome around it. Wired via `claude/.claude/settings.json`'s `statusLine` block (`"command": "ccstatusline"`). Configured interactively (`ccstatusline` run outside a Claude Code session opens its TUI editor) and the result written to `~/.config/ccstatusline/settings.json`; that file is deployed by the **`ccstatusline` package** (in `PACKAGES`) from `ccstatusline/.config/ccstatusline/settings.json` — re-run the TUI and copy the file back into the repo after changing the layout. Installed by `install_ccstatusline()` in `install.sh`, gated behind `WANT_CLAUDE_STACK` (see the Flags section above) — it's the Claude Code statusLine, useless without Claude Code — and version-**pinned** rather than always-latest: ccstatusline writes its own `installation.method`/`installedVersion` back into that same settings file and compares it against the actual npm version to detect drift, so an unreviewed bump could desync the two and trip its own update prompt — bump `pinned_version` in `install_ccstatusline()` deliberately and update the `installation` block in the committed settings file to match. `~/.cache/ccstatusline/` (git-branch cache, usage snapshot) is runtime state, not deployed.

**Idle/permission notifications**: `claude/.claude/settings.json` registers `claude/.claude/scripts/claude-notify.py` as the `Notification` hook with **no matcher** (catch-all — Claude Code's docs were inconsistent on whether `Notification` reliably supports matcher-based filtering, so filtering happens in the script instead). The script checks the hook's `notification_type` field against a `NOTIFY_TYPES` constant at the top of the file (`{"idle_prompt", "permission_prompt"}` by default) — edit that one line to change which notification types surface. Matches are forwarded into zjstatus's existing notification pill via `zellij pipe "zjstatus::notify::<message>"` (zjstatus's own pipe protocol — no `config.kdl` changes needed, `format_center "{notifications}"` already renders it). Side-effect only, per Claude Code's hook docs (`Notification` has no decision control): the script always exits 0 and swallows every failure (missing `zellij`, not inside a session, malformed payload) so it can never block or error a Claude Code session.

**Multi-account switching** (`realiti4/claude-swap`, PyPI package, CLI as `cswap`/`claude-swap`): lets multiple Claude accounts share one machine and rotates between them (manually or automatically) before hitting a rate limit. Not in `PACKAGES` — it owns its own config/credential storage (OS keychain where available, else `0600` files mirroring Claude Code's own storage layout) rather than deploying dotfiles-managed config. Installed by `install_claude_swap()` in `install.sh`, gated behind `WANT_CLAUDE_STACK` (see the Flags section above) — it's a switcher for Claude Code accounts, useless without Claude Code — and requires `uv` (added to `CLI_TOOLS` solely for this — nothing else in the repo needs it): `uv tool install claude-swap` is the exact install method claude-swap's own self-upgrade command (`cswap upgrade`) is built to detect, so once installed the user should upgrade it *with that command*, not by re-running `install.sh --update` repeatedly (which does upgrade it, but claude-swap already handles this itself and nudges the user when a new version lands). Reviewed before adding: it only talks to `pypi.org` (version check) and Anthropic's own `api.anthropic.com`/`platform.claude.com` (OAuth refresh/usage, using the user's own tokens) — no third-party telemetry.

---

## Theme

Catppuccin Mocha everywhere. Palette hex values are in:
- `alacritty/.config/alacritty/themes/catppuccin-mocha.toml` — committed (source of truth for terminal colors)
- `git/.gitconfig` — inline color values for git diff/status output
- `starship/.config/starship.toml` — full palette defined at the bottom of the file (`[palettes.catppuccin_mocha]`)
- `ripgrep/.config/ripgrep/ripgreprc` — match/line highlight colors
- `zellij/.config/zellij/config.kdl` — the `zjstatus` plugin block hardcodes the same hex values inline (no shared palette file with zjstatus)
- `zellij/.config/zellij/themes/catppuccin_mm.kdl` — the Zellij UI theme itself (note: not the stock Catppuccin theme name — this is a locally-tweaked variant, referenced as `theme "catppuccin_mm"` in `config.kdl`)
- `~/.config/zsh/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh` — downloaded by `install.sh` from the official `catppuccin/zsh-syntax-highlighting` port (not committed — same "download to a `$HOME` path directly, not into the repo" pattern as bat's theme below). Sets `ZSH_HIGHLIGHT_STYLES`; `zsh/.zshrc` sources it *before* the `zsh-syntax-highlighting` plugin itself, since the plugin only fills in its own default styles when the array is still unset.
- `~/.config/bat/themes/Catppuccin Mocha.tmTheme` — same pattern, downloaded from `catppuccin/bat` (see `install_tool`'s "Post-download setup" in `install.sh`)
- `~/.config/eza/theme.yml` — same pattern, downloaded from `catppuccin/eza`'s **mauve** accent variant (matches the mauve accent used elsewhere — Starship's directory segment, Zellij's active-tab color). Picked up automatically via `$EZA_CONFIG_DIR`, set in `zsh/.zshenv`. `eza` is aliased over `ls` in `zsh/.config/zsh/aliases.zsh`.

When adjusting colors, check all of the above — they don't share a single source.

---

## Plugin risk notes

Several small/young (or fork-dependent) plugins are load-bearing for navigation and the status bar:
- `fresh2dev/zellij-autolock` — switches Zellij to locked mode for nvim/hx/fzf/zoxide/atuin
- `swaits/zellij-nav.nvim` — Ctrl+hjkl in Neovim with Zellij edge-crossing
- `coder/claudecode.nvim` — Claude Code AI sidebar in Neovim (`<leader>a…`, toggle `<leader>ac`)
- `dj95/zjstatus` — status bar (mode/tab/system pills)
- `AlexZasorin/zellij-newtab-plus` — floating new-tab picker with zoxide
- `zjstatus-hints` — downloaded from tagged releases of our own fork (`myah-mitchell/zjstatus-hints`), because upstream (`b0o/zjstatus-hints`) has no usable release. Since we own the fork and publish our own release tags, this is more stable than depending on a third-party fork branch or building from source.

If any of these becomes unmaintained, the relevant config section will need replacing. They're small enough to fork if needed.

---

## Automated pinned-version bump PRs

`.github/workflows/check-pinned-versions.yml` runs weekly (and on manual dispatch) and opens a PR whenever one of `install.sh`'s hardcoded pins falls behind upstream: the four `ZELLIJ_PLUGINS` release tags and the npm-pinned `ccstatusline` version. It deliberately does **not** cover `CORE_TOOLS`/`CLI_TOOLS` (starship, zellij, bat, fd, rg, ...) — those already resolve `/releases/latest` at install time via `download_release()`, so there's no stale pin to bump. It also does **not** (yet) cover the `ZSH_PLUGINS` array added in the Nushell→zsh migration: the checker script's `github-release` kind queries `/releases/latest`, but none of `zsh-autosuggestions`/`zsh-syntax-highlighting`/`zsh-you-should-use` publish GitHub Releases (tags only, no release asset) — the same repo shape as `ZELLIJ_PLUGINS`' `dest|repo|tag` pins, but the checker would need a `github-tag` kind (querying `/tags` instead) before these could be automated the same way. Bump `ZSH_PLUGINS` manually for now.

Each matrix entry runs `.github/scripts/check-pinned-version.sh`, which extracts the current pin from `install.sh`, queries upstream (GitHub releases API or the npm registry), and — using Perl with values passed through `%ENV` rather than string-interpolated into `-e` source, since release tags/npm versions are untrusted input — rewrites only that one version string in place (for `ccstatusline`, also syncing `ccstatusline/.config/ccstatusline/settings.json`'s `installation.installedVersion`). Each PR carries a review note pointing at the specific manual check called out in this file (e.g. re-syncing `ccstatusline`'s `installedVersion`, or checking a Zellij plugin's `request_permission()` scopes against `ZELLIJ_PLUGIN_PERMISSIONS`) — these bumps are opened for review, never auto-merged.

Requires the repo setting **"Allow GitHub Actions to create pull requests"** enabled (Settings → Actions → General) — without it, the `peter-evans/create-pull-request` step fails to open the PR even though the version-bump commit succeeds.
