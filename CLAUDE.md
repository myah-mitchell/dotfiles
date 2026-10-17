# Architecture and design decisions

This file is for Claude Code sessions working in this dotfiles repo. It records why things are set up the way they are, so a session can make changes without reading every config file first.

## Contents

- [Zellij mode architecture](#zellij-mode-architecture)
- [Unified Ctrl+hjkl navigation](#unified-ctrlhjkl-navigation)
- [Zellij status bar and plugin loading](#zellij-status-bar-and-plugin-loading)
- [Zsh](#zsh)
- [Nushell: optional secondary shell](#nushell-optional-secondary-shell)
- [Config deployment](#config-deployment)
- [Deliberate omissions](#deliberate-omissions)
- [Diff tools: difftastic, delta, diffnav](#diff-tools-difftastic-delta-diffnav)
- [Alias priority chain](#alias-priority-chain)
- [WSL2](#wsl2)
- [Neovim (LazyVim)](#neovim-lazyvim)
- [Claude Code integration](#claude-code-integration)
- [Theme](#theme)
- [Plugin risk notes](#plugin-risk-notes)
- [Pinned-version checks](#pinned-version-checks)
- [SSH: YubiKey resident key retrieval](#ssh-yubikey-resident-key-retrieval)

## Zellij mode architecture

Three modes are in play. Don't conflate them.

| Mode | What it is | When active |
| --- | --- | --- |
| `normal` | Main operating mode (custom) | Default, for all terminal use |
| `tmux` | Prefix layer (custom) | After backtick is pressed |
| `locked` | Zellij's built-in full passthrough | Managed by zellij-autolock, or `Ctrl g` by hand |

`normal` mode intercepts `Ctrl+hjkl` for pane navigation and backtick to enter `tmux` mode. Every other key passes through to the terminal.

`tmux` mode is the prefix layer, like tmux's `C-b`, with backtick as the prefix. Most actions return to `normal` after running.

| Key | Action |
| --- | --- |
| `\` / `-` | Split pane |
| `c` | New tab, via the zellij-newtab-plus floating picker with zoxide directory jump |
| `p` / `n`, `[` / `]` | Previous / next tab |
| `1` to `9` | Jump to tab |
| `hjkl` / `HJKL` | Move focus / move pane |
| `x`, `z`, `f`, `e`, `w` | Close, fullscreen, toggle floating, toggle embed/floating, toggle pane frames |
| `,`, `d`, `q` | Rename tab, detach, quit |
| `o`, `r`, `s`, `/` | Session, resize, scroll, search modes |

`locked` mode sends every keystroke straight to the focused pane. It's never entered by hand except through the `Ctrl g` escape hatch, bound in `shared_except "locked" "tmux"` to enter and inside `locked` to exit. `zellij-autolock` switches to it based on the focused process and back out when that process closes. Don't add keybindings to `locked` beyond the escape hatch.

## Unified Ctrl+hjkl navigation

Two components work together:

1. `fresh2dev/zellij-autolock` (Zellij plugin) watches the focused process. It switches Zellij to `locked` when one of its `triggers` is focused (`nvim|hx|fzf|zoxide|atuin|tmux`, set in `zellij/.config/zellij/config.kdl`) and back to `normal` when it closes.
2. `swaits/zellij-nav.nvim` (Neovim plugin) handles `Ctrl+hjkl` inside Neovim. It moves between splits, and at a window edge calls `zellij action move-focus` to move to the adjacent Zellij pane.

The result: `Ctrl+hjkl` moves between Zellij panes in the terminal, between Neovim splits inside nvim, and across the boundary between the two.

## Zellij status bar and plugin loading

`zellij/.config/zellij/layouts/default.kdl` renders a zjstatus bar (mode pill, tab pills, weather/sysinfo/battery command pills, datetime, username and hostname) plus a zjhints keybinding-hints bar. Both are themed inline in `config.kdl`'s `plugins { ... }` block with Catppuccin Mocha hex values. There's no shared palette file, so a theme change has to be made here too (see [Theme](#theme)).

### Plugins load from local files

`config.kdl` references every plugin as `file:~/.local/share/zellij/plugins/<name>.wasm`. `install.sh` downloads each `.wasm` once into `bin/.local/share/zellij/plugins/`, which `link_package` symlinks into `~/.local/share/zellij/plugins/`, and records the version in `.versions`. A live `https://` location, or a dead pinned tag, would block every new terminal, because these plugins load on every `zellij_autostart`.

Versions are pinned in the `ZELLIJ_PLUGINS` array in `install.sh` and must stay in lockstep with the plugin names used in `config.kdl`:

| Plugin | Source | Notes |
| --- | --- | --- |
| `zellij-autolock.wasm` | `fresh2dev/zellij-autolock` | Tagged release |
| `zjstatus.wasm` | `myah-mitchell/zjstatus` fork | Temporary; see the comment in `ZELLIJ_PLUGINS` for the upstream pin to restore |
| `zellij-newtab-plus.wasm` | `AlexZasorin/zellij-newtab-plus` | Tagged release; powers the `c` binding |
| `zjhints.wasm` | `myah-mitchell/zjhints` | Own repo; temporarily pinned to the moving `nightly` tag, so `--update` picks up new builds |

zellij itself is also temporarily installed from the `myah-mitchell/zellij` fork (see the `TEMPORARY` comment on its `CORE_TOOLS` rows). That fork publishes only a linux-x86_64 asset, so aarch64 and macOS installs fail until it publishes more. Its `TOOL_PINS` entry, `nightly-*`, makes it track the fork's nightly prereleases, so run `install.sh --update` to pick up a newer build (see [Pinning a tool](#pinning-a-tool)). zjhints needs that fork at `fork-v0.46.2` or later, or a nightly built after it.

### Plugin permission pre-seeding

Each plugin's `request_permission()` needs a one-time interactive approval, shown in the plugin's own pane. zjstatus and zellij-autolock live in unfocused, size-1, borderless panes, so that prompt is easy never to see, and the plugin then sits inert with no error. `install.sh` pre-writes the grants to `~/.cache/zellij/permissions.kdl`, appending without touching grants for other plugins. If a plugin bump starts requesting new permission scopes, update its entry in `ZELLIJ_PLUGIN_PERMISSIONS` in `install.sh`.

## Zsh

zsh is the primary shell. Its config lives in the `zsh` package, laid out flat under `$HOME` like the `bash` package rather than XDG-nested, because zsh's bootstrap files have no built-in `$XDG_CONFIG_HOME` awareness and relocating them with `ZDOTDIR` needs a fragile bootstrap trick.

| File | Deployed to | Holds |
| --- | --- | --- |
| `zsh/.zshenv` | `~/.zshenv` | Environment variables only. Sourced by every zsh invocation, including scripts. |
| `zsh/.zshrc` | `~/.zshrc` | Everything else: history and completion options, tool-init sourcing, `zellij_autostart`, the `y` and `sudo` wrappers, keybindings, plugin loading |
| `zsh/.config/zsh/aliases.zsh` | `~/.config/zsh/aliases.zsh` | Aliases, sourced from `.zshrc` |

### Tool-init scripts

Shell-init scripts are sourced from fixed, pre-generated paths rather than generated on the fly, for the same reason the Zellij plugins are local files: they're sourced on every new shell, so generating them each time would add latency to every terminal. Add any new tool that generates an init script the same way.

```text
~/.local/share/atuin/init.zsh    generated by: atuin init zsh --disable-up-arrow
~/.local/share/zoxide/init.zsh   generated by: zoxide init zsh
~/.cache/starship/init.zsh       generated by: starship init zsh
~/.cache/carapace/init.zsh       generated by: carapace _carapace zsh
```

### History

`.zshrc` sets `HISTFILE`, `HISTSIZE`, and `SAVEHIST` plus `setopt SHARE_HISTORY INC_APPEND_HISTORY`. That's only zsh's own backing store; atuin owns searchable history, bound to `Ctrl+R` by its init script. If per-session history isolation is ever wanted, layer it on through atuin's session filtering, since zsh has no shell-level setting for it.

### Plugins

`zsh-autosuggestions`, `zsh-syntax-highlighting`, and `zsh-you-should-use` are loaded directly, not through a framework like oh-my-zsh. Starship, atuin, zoxide, and carapace already own the prompt, history, and completion, so a framework would only add redundant machinery.

They're pinned in the `ZSH_PLUGINS` array in `install.sh` and tracked in `.versions`. None of them publish GitHub Releases, so `install.sh` downloads the source tarball at the pinned tag (`github.com/<repo>/archive/refs/tags/<tag>.tar.gz`) and extracts it into `~/.local/share/zsh/plugins/<name>/`, and `.zshrc` sources each plugin's `.plugin.zsh` from there.

`zsh-syntax-highlighting` must be sourced last, after anything else that wraps zle widgets, or it breaks other plugins' keybindings. Both highlighting plugins are Catppuccin Mocha colored: `zsh-syntax-highlighting` through the downloaded theme (see [Theme](#theme)), `zsh-autosuggestions` through a hand-set `ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE`, since no official port exists for it.

### The sudo wrapper

`sudo`'s `secure_path` in `/etc/sudoers` replaces `PATH`, so `sudo bat` or `sudo rg` can't find tools in `~/.local/bin`. The `sudo` wrapper function in `.zshrc` re-injects `PATH` to fix that.

### Background: the move from Nushell

The primary shell was Nushell until its structured-data model proved incompatible with too many bash-oriented guides and scripts. The last Nushell-based commit is tagged `pre-zsh-migration`. Two Nushell-era helpers have no zsh equivalent because zsh doesn't need them: the `nr <tool>` escape hatch (zsh's builtin `command <tool>` or `\<tool>` bypasses an alias) and a custom `sudo!!` function (zsh's `!!` history expansion makes `sudo !!` work as is). Nushell's per-session history isolation was also left behind; see [History](#history).

## Nushell: optional secondary shell

`install.sh --nushell` makes `nu` available to launch by hand. zsh stays the default shell either way. `WANT_NUSHELL`, computed right after argument parsing like `WANT_CLAUDE_STACK`, gates everything below. The flag is standalone and not implied by `--full`, since Nushell has nothing to do with the IDE-workstation setup `--full` covers.

### What it installs

- A prebuilt `nu` binary, appended to `CORE_TOOLS` with `CORE_TOOLS+=(...)` only when `WANT_NUSHELL` is true. Because the row only exists on `--nushell` runs, `cleanup_orphans()` treats `nu` as orphaned on any `--cleanup` run without `--nushell`, with no dedicated cleanup code.
- The `nushell` config package, added to `PACKAGES` only when `WANT_NUSHELL` is true, so machines that never asked for `nu` don't get an inert `~/.config/nushell`. `--remove` includes it unconditionally (`WANT_NUSHELL == true || DO_REMOVE == true`), since `remove_package()` only deletes symlinks that exist.
- The official `catppuccin/nushell` theme, downloaded into `~/.config/nushell/themes/catppuccin_mocha.nu`.
- `init.nu` scripts for atuin, starship, zoxide, and carapace, generated beside the `init.zsh` ones with the same skip-if-present guards.
- An empty `~/.config/nushell/secrets.nu`, pre-created because Nu's `source` is resolved at parse time and errors if the file is missing.

### Package layout

The package is XDG-nested (`nushell/.config/nushell/{env.nu,config.nu,autoload/aliases.nu}`), because that's where Nu looks for its config.

`env.nu` mirrors the variables in `zsh/.zshenv` (PATH, XDG dirs, editor, diff, ripgrep, bat, eza, fzf, zellij, starship, pager, locale, color), minus two things zsh owns: the ssh-agent bootstrap (any `nu` launched from zsh inherits `SSH_AUTH_SOCK`) and WSL clipboard handling (done by `clip-clean.py` at the Zellij and Neovim layer; see [Clipboard](#clipboard)). Keep the two in sync when either changes.

`autoload/aliases.nu` mirrors the [alias priority chain](#alias-priority-chain), including `ls` to `eza`. `l` uses the same `eza -alg --header --sort=modified` as zsh rather than Nu's `ls -t`, which means "list in parallel", not "sort by time".

### Theme sourcing order

The catppuccin theme works by mutating `$env.config.color_config` and `.explore` when sourced. `config.nu` assigns `$env.config = { ... }` wholesale for everything else, so the theme must be sourced after that assignment or its changes are overwritten. For the same reason, `config.nu`'s own `$env.config` has no `color_config` key.

### Background: cargo-only Nushell plugins

The pre-migration setup also ran three plugins (`nu_plugin_skim`, `nu_plugin_dns`, `nu_plugin_highlight`) that ship no prebuilt binary, so installing them means bootstrapping rustup and cargo. `--nushell` never triggers a cargo bootstrap, so they aren't installed. To add them, follow the shape at the `pre-zsh-migration` tag: a `NUSHELL_PLUGINS_CARGO` array installed through `cargo_install` when `HAVE_CARGO` is true, a registration step (`nu -c "plugin add ...; plugin use ..."`) after configs are linked, and a `plugins:` block in `config.nu`'s `$env.config`.

## Config deployment

`install.sh` deploys configs with its own `link_package()`, `remove_package()`, and `prune_stale_symlinks()` functions. They walk each package directory and symlink every file (or copy it, with `--copy`) into the matching path under `$HOME`, one file at a time.

```text
~/.local/bin/bat -> ~/dotfiles/bin/.local/bin/bat   (symlink created by link_package)
                    the binary itself is gitignored and downloaded by install.sh
```

### Linker behavior

- `PACKAGES` in `install.sh` lists the package directories: `bin bash zsh starship zellij nvim git ripgrep bat yazi atuin lazygit tealdeer ssh alacritty claude ccstatusline`, plus `nushell` under `--nushell`. A new package means adding its directory name here.
- A package can hold a `.linkignore` (one glob per line, `#` comments) listing files not to link. `yazi/.linkignore` excludes `.config/yazi/flavors/*` and `.config/yazi/plugins/*`, which `ya pkg` manages at runtime.
- If `link_package` finds a real file (not a symlink) at a target path, it backs it up to `<target>.bak.<timestamp>` before linking.
- `prune_stale_symlinks()` runs before linking on every invocation. It sweeps `$HOME` (excluding `.cache`, `.cargo`, `.rustup`, `.npm`, `.local/share/nvim`, and the repo itself) for symlinks into the repo whose target is gone, and removes them. `link_package` only creates links for files that exist, so this is what cleans up after a renamed or deleted config file.

### Flags

| Flag | Effect |
| --- | --- |
| `--update` | Force re-download or rebuild of everything |
| `--link` | Skip binary downloads; only re-link configs |
| `--copy` | Copy instead of symlink, for NTFS or shared servers |
| `--remove` | Remove all deployed symlinks and exit; binaries stay |
| `--windows` | Install Windows-side integration under WSL2 |
| `--cargo` | Build Rust tools from source instead of downloading releases; also the only thing that bootstraps rustup and cargo |
| `--claude` | Install the Claude Code stack |
| `--full` | Implies `--claude` and `--windows`; adds PowerShell and nvim's heavier Mason LSPs |
| `--nushell` | Install `nu` and its config (see [Nushell](#nushell-optional-secondary-shell)) |
| `--cleanup` | Remove orphaned and stale local state |
| `--check-pins`, `--upgrade=<name>` | Pinned-version checks (see [Pinned-version checks](#pinned-version-checks)) |
| `--yubikey` | Retrieve FIDO2 resident SSH keys (see [SSH](#ssh-yubikey-resident-key-retrieval)) |

`--windows`, `--claude`, `--full`, and `--nushell` are opt-in; everything else in a default run is on unless a flag turns it off.

#### `--windows`

Only meaningful under WSL2: `WANT_WINDOWS_SETUP`, computed right after `IS_WSL` detection, is false on native Linux and macOS regardless of the flag. It gates the [WSL2](#wsl2) block: installing Alacritty with winget, installing the JetBrainsMono Nerd Font on the Windows side, and creating the Alacritty config symlink. It's opt-in because a WSL box isn't necessarily used through Windows Alacritty at all (a dev container, a CI runner, a headless instance reached over SSH), and those have no business running winget or PowerShell.

#### `--claude` and `--full`

- `WANT_CLAUDE_STACK` (computed right after argument parsing as `--claude || --full`) gates `install_claude()`, `install_node()`, `install_ccstatusline()`, and `install_claude_swap()`. The last three are useless without Claude Code. See [Claude Code integration](#claude-code-integration).
- `--full` additionally gates PowerShell (`pwsh`, a roughly 190MB self-contained tarball needed only by the `powershell_es` LSP) and whether nvim enables its heavier Mason LSPs: `html`, `cssls`, `emmet_language_server`, `bashls`, `pyright`, and the `lang.php` extra (`intelephense`, `phpactor`, `php-cs-fixer`, `phpcs`), roughly 460MB together.
- Node is installed whenever `WANT_CLAUDE_STACK` is true, so "node is on PATH" can't tell nvim whether `--full` was passed. nvim reads a marker file instead (see [`--full`-gated LSPs](#--full-gated-lsps)). `powershell_es` needs no marker: only `--full` installs `pwsh`, so nvim checks `vim.fn.executable("pwsh")`.
- Use `--full` on a full Neovim IDE workstation, `--claude` alone on a machine that wants Claude Code without the IDE extras, and neither on servers and shared boxes that only need the shell environment.

#### `--cleanup`

`install.sh`'s downloaders all overwrite in place, so nothing notices when a tool is removed from the install arrays entirely: its binary and `.versions` entry stay forever. `cleanup_orphans()` handles that:

- It diffs `.versions` against the `CORE_TOOLS`, `CLI_TOOLS`, `ZELLIJ_PLUGINS`, and `ZSH_PLUGINS` arrays, plus a static `known_dest` list for bespoke installers that don't use them (`nvim`, `yazi`, `jetbrainsmono-nf` always; `node` and `ccstatusline` when `WANT_CLAUDE_STACK`; `pwsh` with `--full`). It removes the leftovers: `$BIN_DIR` binaries, Zellij `.wasm` files, zsh plugin directories, and orphaned `npm install -g` packages (checked against `~/.local/lib/node_modules/<key>`, which is how an orphaned `ccstatusline` gets uninstalled).
- `node` is never auto-removed; an orphaned one gets a warning instead. `install_node()`'s `cp -a` merges node's `bin`, `lib`, `include`, and `share` trees into the same `~/.local` directories that dotfiles symlinks and other npm globals use, so unlike `pwsh` in its own `~/.local/lib/powershell`, there's no single path that's safe to delete as "node and nothing else".
- It removes `~/.rustup` and `~/.cargo` when the run isn't `--cargo` (the next `--cargo` run recreates them).
- When the run isn't `--full`, it uninstalls any of the full-only Mason LSP packages (the list under `--full` above) with `nvim --headless -c "MasonUninstall ..."`. Mason downloads aren't installed by `install.sh`, so the `.versions` diff can't catch them.
- It removes old Claude Code versions regardless of `WANT_CLAUDE_STACK`. The native updater puts each version in `~/.local/share/claude/versions/<version>` (300 to 350MB each) and repoints `~/.local/bin/claude`, but never deletes old ones. `cleanup_orphans()` resolves that symlink and deletes every other entry in `versions/`.
- Combined with `--link` it does nothing: the arrays are never populated on a link-only run, so `install.sh` warns and skips rather than judge orphans against an empty set.

When adding a bespoke installer that doesn't go through the four arrays, add its key to `known_dest` too, or `--cleanup` deletes it as an orphan. `yazi` is in that list for this reason: it calls `download_release()` directly instead of going through `CLI_TOOLS`. Its companion binary `ya` never gets a `.versions` entry, so it needs no entry.

### The `homepath` git filter

zjstatus's `command_weather_command`, `command_sysinfo_command`, `command_battery_command`, and Zellij's `copy_command` in `zellij/.config/zellij/config.kdl` need real absolute paths to the scripts in `zellij/.config/zellij/scripts/`. zjstatus execs commands directly: its `src/widgets/command.rs` splits the config string into argv and hands it to `run_command`, with no shell and no `~` or `$HOME` expansion. `config.kdl` is symlinked into `$HOME`, so a literal absolute path would carry whichever machine's username last edited it.

The file in git stores a `__DOTFILES_HOME__` placeholder, and `.gitattributes` marks it `filter=homepath`. `git-filters/homepath-smudge.sh` expands the placeholder to the real `$HOME` on checkout, and `git-filters/homepath-clean.sh` folds it back before staging, so a commit from any machine never contains a machine-specific path.

Filter commands are local git config, not versioned, so `install.sh` registers them (`git config filter.homepath.*`) and re-checks-out the file on every run. That block has three guards:

- It `chmod +x`s `git-filters/homepath-*.sh` before registering the filter, because git execs them directly and a missing exec bit fails silently.
- It deletes `config.kdl` right before `git checkout-index -f`. `-f` only forces overwriting; it doesn't bypass git's stat-based freshness check, so a file whose mtime already matches the index (for example, one checked out before the filter was registered) is silently not re-smudged. Afterwards it greps for a leftover `__DOTFILES_HOME__` and fails loudly if the filter didn't run.
- It runs before the `PACKAGES` linking loop. The ansible role that deploys this repo excludes `config.kdl` from what it copies to the host (see its `sync.yml`), so on a host's first run this checkout is the only thing that creates the file. `link_package` only links files that exist when it walks the package (`find "$pkg_dir" -type f`), so if this block ran after the loop, `~/.config/zellij/config.kdl` would silently never be linked on a first run.

Neovim's clipboard `copy` entry in `nvim/.config/nvim/lua/config/autocmds.lua` has the same no-shell-expansion constraint but doesn't need the filter: it's Lua, evaluated on the machine running it, so it computes the path with `vim.fn.expand("~/.config/zellij/scripts/clip-clean.py")`. If another file has this problem, check whether it's executable config that can compute its own path before reaching for the filter, which is only for static data read as is by something that doesn't invoke a shell.

### Executable scripts

The four scripts in `zellij/.config/zellij/scripts/` (`weather.py`, `sysinfo.py`, `battery.py`, `clip-clean.py`) must stay executable in git. zjstatus and Neovim's clipboard provider invoke them directly, so a missing exec bit fails silently as `Permission denied`: copy or the pills just stop working, with no error in the terminal.

### Version tracking and the run log

`install.sh` records installed binary and plugin versions in `~/.local/bin/.versions`, the deployed path under `$HOME` (gitignored, regenerated by `install.sh`). A re-run skips anything that already has a recorded version, unless a [tool pin](#pinning-a-tool) selects a different one; `--update` forces everything to re-check.

Every invocation appends its full output to `~/.local/state/dotfiles/install.log`. Logging starts right after argument parsing, before the early-exit flags (`--check-pins`, `--upgrade`, `--yubikey`, `--remove`), so those runs are logged too. It exists because `.versions` and the `full-install` marker are overwritten each run and record no history. Each run is bracketed by timestamped `=== ... ===` lines, with the exit status in the footer. A `sed` filter in the `tee` pipeline strips ANSI colors from the file while the terminal stays colored. The log is trimmed to its most recent 5000 lines at the start of each run and isn't touched by `--cleanup`.

### Adding a tool

Follow the `download_release()` pattern in the `CORE_TOOLS` and `CLI_TOOLS` arrays: `dest|crate|repo|os|arch|asset-glob|binary-name-in-archive`, fetched through the GitHub releases API and compared against `.versions`. Each platform gets its own row: use `darwin|*` only when the asset is a universal macOS build, since `*` takes whichever architecture's asset matches first. Set `GITHUB_TOKEN` before a fresh install: unauthenticated GitHub API calls are capped at 60 an hour, and installing 25 or more tools from scratch can hit that.

### Pinning a tool

`CORE_TOOLS` and `CLI_TOOLS` rows install `/releases/latest` unless the tool has a row in `TOOL_PINS`, in the pinned-dependency registry near the top of `install.sh`. The format is `dest|owner/repo|selector`, and it applies to every platform row of that `dest`, including yazi's direct `download_release()` calls.

| Selector | Installs | Picks up a new release |
| --- | --- | --- |
| Exact tag, such as `v1.27.0` | That release | When the pin changes, even without `--update`; bump it with `--upgrade=<dest>` |
| Prefix ending in `*`, such as `nightly-*` | The newest release whose tag starts with the prefix, prereleases included | With `--update` |

The pin only applies while its repo matches the row's repo. A mismatch is ignored with a warning, so moving a tool to another repo (such as reverting the zellij fork) can't keep a pin meant for the old one. Under `--cargo`, an exact `X.Y.Z` or `vX.Y.Z` pin becomes `cargo install --version`; any other selector builds the newest crate, with a warning.

## Deliberate omissions

Don't add these.

| What | Why not |
| --- | --- |
| A `top` replacement | `btm` (bottom) is a standalone addition, not a `top` alias |
| A `sed` replacement | `sd` is a standalone tool, not a `sed` alias; the syntax differs enough to break scripts |
| A `ping` replacement | `gping` is an additional visual tool and doesn't replace `ping` |
| System package installs | Everything goes into `~/.local/`. The only exceptions are `mosh` (no release binaries) and upgrading `git` from the git-core PPA on Ubuntu when it's older than 2.35 (needed for the `zdiff3` merge style). zsh also has no prebuilt cross-platform binary, but `install.sh` requires it pre-installed and errors with instructions rather than adding a third exception. |

## Diff tools: difftastic, delta, diffnav

Three tools are layered deliberately rather than one replacing another:

- difftastic (`difft`) is the default everywhere: `GIT_EXTERNAL_DIFF=difft` in `zsh/.zshenv` and `nushell/env.nu`, aliased over `diff`, plus the `dft*` git aliases. Plain `git diff` uses it.
- delta is a syntax-highlighting pager for ordinary unified diffs, for when difftastic's structural view isn't what you want. Opt in with the `dd*` git aliases or the `gdd` and `gdds` shell aliases.
- diffnav is a GitHub-style file-tree browser over a unified diff. It shells out to `delta` by name (`exec.Command("delta", ...)`) for every file, so delta is a hard prerequisite, and it wants a Nerd Font for its tree icons (installed by `install.sh`). Opt in with the `dn*` git aliases or the `gdn` and `gdns` shell aliases.

### Integration details

- The `dd*` and `dn*` aliases use `--no-ext-diff`, not `-c diff.external=`. Both tools need a real unified diff on stdin, and `GIT_EXTERNAL_DIFF` takes precedence over the `diff.external` config (see `diff.external` in `git help config`), so only `--no-ext-diff` turns difftastic off. Without it, diffnav fails softly: its `isUnifiedDiff` check prints the input back and exits, which looks like "diffnav did nothing". Its `--watch-cmd` re-runs `git diff` and inherits the variable too, so pass `--watch-cmd "git diff --no-ext-diff"`.
- `color.ui = always` in `git/.gitconfig` is safe for both, even though forced color usually breaks diff parsers: delta reads git's colored output by design, and diffnav runs `ansi.Strip` over stdin before parsing.
- The `[delta]` block in `git/.gitconfig` sets colors and `syntax-theme` only, with no `side-by-side` or `line-numbers`. diffnav re-invokes delta with its own arguments and passes `--side-by-side` only when it wants it, never `--side-by-side=false`, so a config default would override its unified view, and line-number columns would eat its viewport width. Syntax highlighting comes from bat's theme cache (`install.sh` runs `bat cache --build` with the Catppuccin theme in place); `syntax-theme` is set explicitly so it applies to callers that don't have `$BAT_THEME`.

### Release asset gaps

delta publishes no aarch64 musl build and no x86_64 macOS build, so its `CLI_TOOLS` rows are `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-gnu`, and `aarch64-apple-darwin` only. Its crate is `git-delta` (binary `delta`) for the `--cargo` path. diffnav is Go, so its crate field is `-`.

## Alias priority chain

1. Specialty tools override their equivalents in `zsh/.config/zsh/aliases.zsh`: `bat` for `cat`, `fd` for `find`, `rg` for `grep`, `difft` for `diff`, `procs` for `ps`, `viddy` for `watch`, `tspin` for `tail`, `zoxide` for `cd`, `eza` for `ls`.
2. `command <tool>` or `\<tool>` is zsh's builtin escape hatch to the system binary, bypassing the alias: `command du -sh .` runs `/usr/bin/du`.

## WSL2

### Alacritty config symlink chain

Alacritty runs natively on Windows and reads `%APPDATA%\alacritty\alacritty.toml`. `install.sh --windows` creates an NTFS symlink from there into the WSL2 filesystem:

```text
%APPDATA%\alacritty\alacritty.toml
  -> \\wsl$\<distro>\home\<user>\.config\alacritty\alacritty.toml   (NTFS symlink, created through powershell.exe)
    -> ~/dotfiles/alacritty/.config/alacritty/alacritty.toml        (symlink, created by link_package)
```

The NTFS symlink needs Windows Developer Mode. Without it, `windows-setup.ps1` falls back to `Copy-Item`, so the config is a plain copy refreshed on every `install.sh` run instead of a live link, and `install.sh` prints a manual fallback if that fails too. The same script installs Alacritty with winget and the JetBrainsMono Nerd Font: the `JetBrainsMonoNerdFont*` files (NF, NFM, NFP), not the NL no-ligature variant.

### Clipboard

Three layers keep everything in sync with the Windows clipboard. Zellij and Neovim both copy through `zellij/.config/zellij/scripts/clip-clean.py` rather than `clip.exe`, so Nerd Font glyphs in copied text (branch icons, status pills) don't paste as tofu boxes somewhere without the font.

| Layer | Setting |
| --- | --- |
| Zellij | `copy_on_select true` and `copy_command` pointing at `clip-clean.py`. `copy_clipboard "system"` stays as an inert fallback while `copy_command` is set. |
| Alacritty | `save_to_clipboard = true`, so mouse selections copy |
| Neovim | `vim.opt.clipboard = "unnamedplus"`, with `vim.g.clipboard.copy` pointing at `clip-clean.py` and paste through PowerShell `Get-Clipboard` (in `autocmds.lua`) |

`clip-clean.py` must stay executable, and its path in `config.kdl` comes from the `homepath` filter. Both fail silently; see [Config deployment](#config-deployment).

### WSL2 detection and distro name

`install.sh` detects WSL2 with `grep -qi microsoft /proc/version`. Only under WSL2 does the Windows section run; on native Linux and macOS, `install.sh` downloads the Nerd Font itself instead (the "Fonts (Linux / macOS only)" section of the script).

The `\\wsl.localhost\<distro>\...` path for the Alacritty target comes from `$WSL_DISTRO_NAME`, which WSL sets for the session. The fallback, `wsl.exe --list --running --quiet | head -1`, is unreliable when more than one distro is registered or running, since list order doesn't guarantee the current distro comes first. A wrong guess silently points the config at a path that doesn't exist and leaves `%APPDATA%\alacritty\alacritty.toml` missing, which breaks `Ctrl+C` and OSC52 copy in the shell with no obvious error.

## Neovim (LazyVim)

The Neovim config is LazyVim-based. Keep changes idiomatic: reach for an official LazyVim extra or a standard spec pattern before hand-rolling anything, and look in `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/` for one. Responsibilities are split: Zellij is the chrome (tabs, status bar, panes), Neovim is the editor.

### Layout

- File sidebar: Snacks explorer through the official `snacks_explorer` extra (imported in `lua/config/lazy.lua`), on `<leader>e`. `plugins/snacks.lua` sets `picker.sources.explorer.hidden = true`, which this repo needs because nearly everything in it is a dot-directory or dotfile; without it most package folders expand to nothing. `ignored` stays off so downloaded binaries under `bin/.local/` don't flood the tree. `H` and `I` toggle hidden and ignored at runtime.
- Status bar: lualine is disabled (`plugins/lualine.lua`, `enabled = false`) with `laststatus=0` in `config/options.lua`, because zjstatus already shows mode, git, clock, and system info. Per-window info comes from `incline.nvim` (`plugins/incline.lua`), a floating top-right label with filetype, line count, size, indent, diagnostics, git-diff counts, and a modified or read-only marker. It leaves out the filename because dropbar's winbar shows it.
- Location in file: `dropbar.nvim` (`plugins/dropbar.lua`) renders breadcrumbs (`folder > file > Symbol`) in each window's winbar, falling back to treesitter symbols without an LSP. The `ui.treesitter-context` extra pins the enclosing scope (function, class, loop) to the top while scrolling.
- AI sidebar: `coder/claudecode.nvim` (`plugins/claudecode.lua`, `<leader>a` prefix, toggle `<leader>ac`) speaks the same MCP/WebSocket protocol as the VS Code extension. Claude Code is the only AI integration wanted, so don't add others such as `opencode.nvim`. `claude` is on `$PATH` at `~/.local/bin/claude`, so there's no `terminal_cmd` override.
- Terminal: the snacks terminal, docked at the bottom on `<c-/>`. `zellij_autostart` in `.zshrc` checks `$NVIM`, so a terminal inside Neovim never starts a nested Zellij session.

### Language support

LazyVim `lang.*` extras are used where they exist:

- `lang.rust`: rust-analyzer, always on, no Node needed.
- `lang.python`: pinned to pyright through `vim.g.lazyvim_python_lsp` in `options.lua`, not basedpyright, which installs through pip (not available here).
- `lang.php`: intelephense, a pure-Node analyzer, so no PHP runtime is needed.
- `lang.markdown`: marksman, markdownlint-cli2, markdown-toc, prettier (see [markdownlint defaults](#markdownlint-defaults)).

HTML, CSS, Emmet, and Bash have no lang extras, so their servers are declared in `plugins/lsp-servers.lua`. Those, `pyright`, and the `lang.php` extra are all npm packages installed by Mason, which is why `install.sh` installs a Linux Node.js into `~/.local` under `WANT_CLAUDE_STACK`. The Windows `npm` that leaks onto PATH through WSL interop would install unusable Windows binaries; `zsh/.zshenv` prepends `~/.local/bin` so the Linux one wins.

ruff is pip-based in Mason, so `install.sh` installs it as a standalone binary and `plugins/lsp-servers.lua` sets `ruff = { mason = false }`. It's always on.

PowerShell (`powershell_es`) runs on `pwsh`, which `install.sh --full` installs as a self-contained tarball into `~/.local/lib/powershell`, symlinked to `~/.local/bin/pwsh`. It bundles its own .NET runtime, and Mason supplies the PowerShell Editor Services bundle.

Treesitter parsers for all seven languages are in `plugins/treesitter.lua`, so highlighting works even where an LSP can't be installed.

### markdownlint defaults

`markdownlint-cli2` (through `nvim-lint`) flags MD013 (line length) and MD041 (first line must be a top-level heading) by default, both too noisy to want everywhere. `plugins/lint.lua` extends the linter's args through LazyVim's `opts.linters` (see `lazyvim.plugins.linting`) to add `--config <nvim config dir>/.markdownlint.yaml`, pointing at `nvim/.config/nvim/.markdownlint.yaml`, which turns both off. `--config` sets the base config rather than replacing discovery, so a project's own `.markdownlint.yaml` or `.markdownlint-cli2.yaml` still layers on top and can turn either rule back on. The path is computed with `vim.fn.stdpath("config")` at load time.

### `--full`-gated LSPs

`html`, `cssls`, `emmet_language_server`, `bashls`, `pyright`, and the `lang.php` extra come to roughly 460MB once Mason downloads them, so they're only enabled on a full IDE workstation.

- `install.sh` writes or removes the marker file `~/.local/state/dotfiles/full-install` on every run, based on `--full`.
- `config/lazy.lua` reads the marker to decide whether to `table.insert` the `lang.php` extra into its spec.
- `plugins/lsp-servers.lua` reads it to decide whether to declare `html`, `cssls`, `emmet_language_server`, and `bashls`, and sets `servers.pyright = false` outside `--full` to override `lang.python`'s own pyright config. That's LazyVim's documented way to opt a server out: `false` is normalized to `{ enabled = false }` in `lazyvim.plugins.lsp.init`, which skips `vim.lsp.enable()` and removes it from `mason-lspconfig`'s `ensure_installed`.
- The marker is needed because Node is installed under `--claude` as well as `--full`, so `vim.fn.executable("node")` can't tell the two apart.
- Changing `--full` changes what nvim enables on its next launch but doesn't uninstall what Mason already downloaded. `install.sh --cleanup` removes those (see [`--cleanup`](#--cleanup)), or use `:MasonUninstall <package>`.
- `lang.markdown`'s Node tooling (about 30MB) is deliberately not gated: it's small, and useful on any machine.

### Lockfile

`lazy-lock.json` is gitignored: plugin versions are deliberately not pinned across machines the way `.versions` pins tools. If `:Lazy sync` fails writing it, check that the file isn't root-owned and `chown` it back.

Two things must not be removed: the catppuccin theme and the Ctrl+hjkl Zellij navigation (see [Unified Ctrl+hjkl navigation](#unified-ctrlhjkl-navigation)).

## Claude Code integration

### The `claude` CLI

`install_claude()` installs it under `WANT_CLAUDE_STACK`, using the official native installer (`curl -fsSL https://claude.ai/install.sh | bash`). The installer manages its own launcher at `~/.local/bin/claude`, a symlink into `~/.local/share/claude/versions/<version>`, and updates itself in the background, so `install_claude()` records no version in `.versions`. `--update` runs `claude update` to force an immediate check. `--cleanup` prunes old version directories regardless of `WANT_CLAUDE_STACK` (see [`--cleanup`](#--cleanup)).

### The `claude` package

Deployed unconditionally, since it's config only. It links:

| Source | Target | Contents |
| --- | --- | --- |
| `claude/.claude/settings.json` | `~/.claude/settings.json` | Settings, the status line, and the notification hook |
| `claude/.claude/keybindings.json` | `~/.claude/keybindings.json` | Maps `alt+enter`, `shift+enter`, and `ctrl+enter` to `chat:newline` |
| `claude/.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Global instructions for every session: pushing back on requests, codebase conventions, the `/create-commits` and `/push-changes` workflow, Conventional Commits, documentation, writing style |
| `claude/.claude/skills/*/` | `~/.claude/skills/*/` | Skills, linked one file at a time; a new skill needs an `install.sh --link` run before it appears |

Only `alt+enter` actually reaches Claude Code over WSL2, Windows Terminal, and Zellij: Shift+Enter and Ctrl+Enter both arrive as bytes already claimed by something else. The other two bindings are harmless and stay in case the terminal side starts telling them apart.

Documentation standards live in the `doc-standards` skill rather than in `CLAUDE.md`, so they load only when docs are being written. Its `SKILL.md` is a general, condensed version of the fleet-docs Markdown style guide, and `reference/markdown-style-guide.md` is a copy of the full guide from the fleet-docs commit named at the bottom of `SKILL.md`. Re-copy it by hand when the upstream guide changes.

### Status line

`sirmalloc/ccstatusline` (npm) renders the status line inside the Claude Code TUI: model, thinking effort, git branch and changes, context usage, compaction count, 5-hour and weekly reset timers, token breakdown. It's separate from the zjstatus pills around it. `claude/.claude/settings.json` wires it in with `"statusLine": { "command": "ccstatusline" }`.

Its layout is configured interactively (running `ccstatusline` outside a Claude Code session opens its editor) and saved to `~/.config/ccstatusline/settings.json`, which the `ccstatusline` package deploys from `ccstatusline/.config/ccstatusline/settings.json`. After changing the layout, copy the file back into the repo.

`install_ccstatusline()` installs it under `WANT_CLAUDE_STACK`, pinned to a fixed version. ccstatusline writes `installation.method` and `installedVersion` into its settings file and compares them against the installed npm version, so an unreviewed bump would trip its own update prompt. Bump `pinned_version` in `install_ccstatusline()` deliberately and update the `installation` block in the committed settings file to match. `~/.cache/ccstatusline/` is runtime state and isn't deployed.

### Idle and permission notifications

`claude/.claude/settings.json` registers `claude/.claude/scripts/claude-notify.py` as the `Notification` hook with no matcher. Claude Code's documentation doesn't clearly guarantee matcher filtering for `Notification`, so the script filters instead: it checks the hook's `notification_type` against `NOTIFY_TYPES` at the top of the file (`{"idle_prompt", "permission_prompt"}`). Edit that line to change which notifications surface.

Matches go to zjstatus's notification pill through `zellij pipe "zjstatus::notify::<message>"`, zjstatus's own pipe protocol, which `format_center "{notifications}"` already renders. `Notification` hooks have no decision control, so the script always exits 0 and swallows every failure (no `zellij`, not in a session, malformed payload); it can never block or break a session.

### Multi-account switching

`realiti4/claude-swap` (PyPI, CLI `cswap` or `claude-swap`) lets several Claude accounts share one machine and rotates between them, manually or automatically, before a rate limit hits. It isn't in `PACKAGES`: it owns its own config and credential storage (the OS keychain where available, otherwise `0600` files mirroring Claude Code's layout).

`install_claude_swap()` installs it under `WANT_CLAUDE_STACK` with `uv tool install claude-swap`, which is why `uv` is in `CLI_TOOLS`; nothing else needs it. That's the install method `cswap upgrade` detects, so upgrade it with `cswap upgrade`. `install.sh --update` also works, but claude-swap already prompts when a new version is out. It talks only to `pypi.org` (version check) and Anthropic's `api.anthropic.com` and `platform.claude.com` (OAuth refresh and usage, with the user's own tokens), with no third-party telemetry.

## Theme

Catppuccin Mocha everywhere. The palette has no single source, so when adjusting colors, check all of these:

| Location | Holds |
| --- | --- |
| `alacritty/.config/alacritty/themes/catppuccin-mocha.toml` | Terminal colors (the source of truth) |
| `git/.gitconfig` | Inline colors for diff and status output, plus the `[delta]` style keys |
| `starship/.config/starship.toml` | The full palette, in `[palettes.catppuccin_mocha]` at the bottom |
| `ripgrep/.config/ripgrep/ripgreprc` | Match and line highlight colors |
| `zellij/.config/zellij/config.kdl` | zjstatus and zjhints colors, inline |
| `zellij/.config/zellij/themes/catppuccin_mm.kdl` | The Zellij UI theme, a locally tweaked variant referenced as `theme "catppuccin_mm"` |
| `~/.config/zsh/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh` | Downloaded by `install.sh` from `catppuccin/zsh-syntax-highlighting`; not committed |
| `~/.config/bat/themes/Catppuccin Mocha.tmTheme` | Downloaded from `catppuccin/bat` (see "Post-download setup" in `install_tool`); not committed |
| `~/.config/eza/theme.yml` | Downloaded from `catppuccin/eza`'s mauve variant; not committed |

The zsh-syntax-highlighting theme sets `ZSH_HIGHLIGHT_STYLES`, and `zsh/.zshrc` sources it before the plugin itself, because the plugin only fills in its defaults when the array is unset. The eza theme uses the mauve accent to match Starship's directory segment and Zellij's active tab, and eza finds it through `$EZA_CONFIG_DIR`, set in `zsh/.zshenv`.

## Plugin risk notes

Several small or young plugins, some on forks, carry navigation and the status bar:

| Plugin | Role |
| --- | --- |
| `fresh2dev/zellij-autolock` | Switches Zellij to locked mode for the autolock triggers |
| `swaits/zellij-nav.nvim` | Ctrl+hjkl in Neovim, crossing into Zellij panes |
| `coder/claudecode.nvim` | Claude Code sidebar in Neovim |
| zjstatus (`dj95/zjstatus`, temporarily the `myah-mitchell/zjstatus` fork) | Status bar |
| `AlexZasorin/zellij-newtab-plus` | Floating new-tab picker with zoxide |
| `myah-mitchell/zjhints` | Keybinding-hints bar; own repo, so releases are under direct control |

If one becomes unmaintained, its config section needs replacing. They're all small enough to fork.

## Pinned-version checks

### Weekly bump PRs

`.github/workflows/check-pinned-versions.yml` runs weekly and on manual dispatch, and opens a PR when one of `install.sh`'s hardcoded pins falls behind upstream. It covers the `ZELLIJ_PLUGINS` release tags, the npm-pinned `ccstatusline`, and any exact-tag `TOOL_PINS` row given a `tool-release` matrix entry (none yet). Unpinned `CORE_TOOLS` and `CLI_TOOLS` rows resolve `/releases/latest` at install time and so have no stale pin, and a `*` prefix pin always tracks the newest match. It doesn't cover `ZSH_PLUGINS` either: those repos publish tags but no GitHub Releases, and the checker has no `github-tag` kind yet, so bump them by hand or with `--upgrade`.

Each matrix entry runs `.github/scripts/check-pinned-version.sh`, which reads the current pin from `install.sh`, queries upstream (GitHub releases or the npm registry), and rewrites that one version string in place with Perl, passing values through `%ENV` rather than interpolating them into the `-e` source, because tags and versions are untrusted input. For `ccstatusline` it also syncs `installation.installedVersion` in `ccstatusline/.config/ccstatusline/settings.json`. Each PR carries a review note naming the manual check this file calls for (re-syncing ccstatusline's `installedVersion`, or checking a Zellij plugin's `request_permission()` scopes against `ZELLIJ_PLUGIN_PERMISSIONS`). Below the note, the PR body has the upstream GitHub release notes for every release since the old pin, with `@mentions` turned into code spans and every GitHub link and `#123` or `owner/repo#123` ref sent through `redirect.github.com`. The repo is public, so a direct link or qualified ref would add a "mentioned this" entry to the upstream issue's timeline, and only GitHub Support can remove one. The PRs are for review, never auto-merged.

The workflow needs the repo setting *Allow GitHub Actions to create pull requests* (under *Settings > Actions > General*). Without it, the `peter-evans/create-pull-request` step can't open the PR, even though the bump commit succeeds.

### `--check-pins` and `--upgrade`

`./install.sh --check-pins` prints the `ZELLIJ_PLUGINS`, `ZSH_PLUGINS`, `ccstatusline`, and `TOOL_PINS` pins next to their current upstream versions and exits, without downloading anything.

`./install.sh --upgrade=<name>` (for example `--upgrade=zjstatus.wasm` or `--upgrade=ccstatusline`) bumps exactly one pin: it rewrites the pin in `install.sh` with `sed`, installs it, prints the same review note a bump PR would carry, and exits, leaving the change unstaged for review. The fetched tag is validated against `^[A-Za-z0-9._-]+$` first, because it's untrusted input spliced into the script's own source and `sed` has no `%ENV`-style passthrough. It's one dependency per run for the same reason each bump PR is reviewed on its own. For a `TOOL_PINS` name it only rewrites the pin, because the tool rows aren't declared that early in the script; the next normal run installs it. A `*` prefix pin has nothing to bump.

Both flags share their lookup logic with the CI script, plus a `github-tag` lookup for `ZSH_PLUGINS` that prefers clean `vX.Y.Z` tags over pre-release ones. A plain `sort -V` gets this wrong: in `zsh-users/zsh-syntax-highlighting`, `0.8.0-alpha1-pre-redrawhook` sorts above `0.8.0` even though it's older. Both flags run before the zsh, git, and locale prerequisite checks, so a version check never triggers a `sudo` install.

## SSH: YubiKey resident key retrieval

`./install.sh --yubikey` retrieves SSH keys already stored as FIDO2 resident keys on a YubiKey (or any FIDO2 authenticator) with `ssh-keygen -K`, which writes them into `~/.ssh/`. It only retrieves: if the key has no resident key yet, provision one first with `ssh-keygen -t ed25519-sk -O resident`. Like `--check-pins`, it runs on its own and exits.

`ssh-keygen -K` names its output files from what's stored on the key, so they land in `~/.ssh/` directly. The committed `ssh/.ssh/config` only knows `~/.ssh/id_ed25519` and `id_rsa`, so the flag prints a reminder to add an `IdentityFile` line by hand rather than guessing a filename to write into committed config.

### Design choices

- FIDO2 resident keys rather than PIV/PKCS#11 (`ykcs11.so`, key used live through `PKCS11Provider`) or gpg-agent's SSH support. `ssh-keygen -K` is the standard OpenSSH 8.2+ way to set up an existing identity on a new machine, and it needs only an OpenSSH client with security-key support: no yubico-piv-tool, pcscd, or gpg-agent.
- No dependency preflight and no `apt install`. Detecting FIDO2 support up front is fragile (package names, whether libfido2 is linked in or loaded as an external provider, and provider search paths all vary by distro), so `pull_yubikey_ssh_key()` runs the real operation and classifies any failure from its output, like the zsh-presence check does. See [Deliberate omissions](#deliberate-omissions) for the only `apt` exceptions.
- Streamed output. Retrieval needs a physical touch and may prompt for a PIN, so `ssh-keygen -K`'s output goes straight to the terminal through `tee`, with the copy kept only to classify a failure afterwards. `install.sh` runs under `set -eo pipefail`, so the pipeline is the condition of an `if` (an exemption from `set -e`); as a bare statement, the expected "no key plugged in" failure would abort the script before classification runs.
- Classification order. An OpenSSH 10.x client with FIDO2 linked in prints `Provider "internal" returned failure -4` and `Unable to load resident keys: device not found` when no key is plugged in. The broad `provider` match for "libfido2 is missing" must be checked after the specific "device not found" pattern, or the common case is misreported as a missing library.

### WSL2 USB passthrough

WSL2 is a VM, so a plugged-in YubiKey is invisible to it until bridged over with usbipd. This isn't automated in `--windows`: binding needs the physical key, a `BUSID` only a person can read off, and a one-time Windows admin elevation. Set it up once by hand:

1. On Windows, run `winget install usbipd`, then `usbipd list` with the YubiKey plugged in and note its `BUSID`.
2. On Windows, once per device, run `usbipd bind --busid <busid>` as admin.
3. On Windows, each session the key is needed, run `usbipd attach --wsl --busid <busid>`. Adding `--auto-attach` reattaches on reconnect but doesn't survive a reboot without extra Windows-side scheduling.
4. In WSL2, `lsusb` shows the Yubico device. `./install.sh --yubikey`, `ssh-keygen -t ed25519-sk -O resident`, and ordinary `ssh` or `git` with an sk key then work as on native Linux. This works on stock Ubuntu-on-WSL2 with no custom kernel, per [Daniel Nashed's writeup](https://blog.nashcom.de/nashcomblog.nsf/dx/using-fido2-yubikey-on-wsl-for-ssh.htm).

Two problems seen in some setups, not all, so try without these fixes first:

- If `/dev/hidraw*` is root-owned, `ssh-keygen` needs `sudo` until a udev rule grants access, for example `KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess", MODE="0666"`. That's from [this FIDO2-on-WSL2 writeup](https://lgug2z.com/articles/yubikey-passthrough-on-wsl2-with-full-fido2-support/), which also built a custom kernel with `HIDRAW` and `HIDDEV` enabled; the stock-kernel setup above didn't need that.
- `-O resident` needs a FIDO2 PIN set on the YubiKey, and none is set by default (same source).
