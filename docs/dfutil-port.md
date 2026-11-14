# dfutil port

This repo carries a `dfutil.toml` manifest beside `install.sh`. The manifest describes the same tools, packages, and presets that `install.sh` installs, for use with dfutil. `install.sh` and every existing package stay in place, so both systems work from the same checkout.

This page maps `install.sh` concepts to dfutil, lists the exact edits needed to switch a machine over, and records what dfutil can't express yet.

## Contents

- [Layout](#layout)
- [Presets](#presets)
- [How install.sh maps to dfutil](#how-installsh-maps-to-dfutil)
- [Templates and palettes](#templates-and-palettes)
- [Switching a machine to dfutil](#switching-a-machine-to-dfutil)
- [Not ported](#not-ported)
- [Gaps in dfutil](#gaps-in-dfutil)
- [Validation](#validation)
- [Background](#background)

## Layout

| Path | Purpose |
| --- | --- |
| `dfutil.toml` | Settings, packages, tools, and presets |
| `palettes/mocha.toml`, `palettes/latte.toml` | The 26 Catppuccin color names for each flavor |
| `scripts/` | Helpers that script tools and `post_install` hooks run from the repo root |
| `zellij/.config/zellij/config.kdl.tmpl` | Zellij config with home path, plugin path, and colors as placeholders |
| `starship/.config/starship.toml.tmpl` | Starship config with the palette block rendered from the active palette |
| `zellij/.linkignore`, `starship/.linkignore` | Keep the untemplated originals from deploying beside the rendered files |

The `bin` package has no entry in `dfutil.toml`. It is the directory `install.sh` downloads binaries into, and dfutil keeps tools under `~/.local/share/dfutil/tools` and links them into `~/.local/bin` itself.

## Presets

The presets mirror the `install.sh` flags. `settings.presets` selects `base`, `settings.shells` selects `zsh`, and `settings.palette` selects `mocha`.

| Preset | Equivalent flag | Adds |
| --- | --- | --- |
| `base` | none | Core and CLI tools, Zellij and zsh plugins, themes, the Nerd Font on native Linux, and every package except `nushell` |
| `claude` | `--claude` | `claude`, `node`, `ccstatusline`, `claude-swap` |
| `full` | `--full` | `claude` plus `pwsh`, the `full-marker` tool, and `windows-setup` |
| `windows` | `--windows` | `windows-setup`, which only runs under WSL2 |
| `nushell` | `--nushell` | `nu`, `nushell-extras`, the `nushell` package, and the nushell init script |
| `cargo` | `--cargo` | `build = "source"`, `rustup`, and `cargo-clean-all` with its weekly timer |

`full` lists `windows-setup` directly instead of extending `windows`, because `--full` implies `--windows` and the tool's `when = { wsl = true }` makes it a no-op elsewhere.

## How install.sh maps to dfutil

### Release binaries

Every row of `CORE_TOOLS` and `CLI_TOOLS` is a `github` tool with `repo`, `assets.linux-x86_64`, `assets.linux-aarch64`, and, where `install.sh` has one, `crate` for source builds. Darwin rows are dropped.

- The tool name is `install.sh`'s `dest`, so `rg`, `trip`, `btm`, and `tree-sitter-cli` keep their names. `bins` is set only where the name inside the archive differs (`yazi` and `ya`, `nvim=bin/nvim`, `tree-sitter-cli=tree-sitter`).
- Globs are copied from `install.sh` with three exceptions: `lazygit` and `glow` match the casing and `difft` the version segment that current releases use, and `rg` on aarch64 picks the musl build because the old pattern matched two assets. dfutil matches case-sensitively against the whole asset name, so the globs need checking against real releases whenever an upstream renames assets.
- `tree-sitter-cli` uses the `.zip` asset. Upstream publishes no bare `tree-sitter-cli-linux-x64` asset.
- Tools with no aarch64 Linux asset (`rga`, `choose`, `procs`, `sd`, `presenterm`, `mdcat`) carry `when = { arch = "x86_64" }`. Without it, dfutil rejects the whole config on aarch64.
- `7zz` has no `crate`: crates.io has no crate of that name, so a source build can't work for it. `install.sh` lists one.
- The `TOOL_PINS` entry for zellij becomes `pin = "fork-ea-v0.46.7-*"` on the `myah-mitchell/zellij` fork. The fork publishes only x86_64, and the aarch64 asset glob stays so an aarch64 install fails at install time exactly as `install.sh` does.

### Shell init scripts

`starship`, `zoxide`, `atuin`, and `carapace` carry `init.zsh`, and where meaningful `init.bash` and `init.nushell`, commands. dfutil writes each to `~/.local/share/dfutil/init/<tool>.<ext>` and aggregates them into `init.zsh`, `init.bash`, and `init.nu` for the selected shells. These replace the four fixed paths `install.sh` generates.

### Zellij plugins

Each plugin is a `github` tool with `links` to `share/zellij/plugins/<name>.wasm`, which is the path `config.kdl` loads from today. The pins carry over:

| Plugin | Pin | Kind of pin |
| --- | --- | --- |
| `zellij-autolock` | `tag:0.3.0` | Exact tag |
| `zjstatus` | `tag:fork-v0.25.1` | Exact tag, on the `myah-mitchell/zjstatus` fork |
| `zellij-newtab-plus` | `tag:v0.6.0` | Exact tag |
| `zjhints`, `zjtabs` | `ea-v0.6.0-*` | Prefix, newest by publish date |

Permission pre-seeding is each plugin's `post_install`, which runs `scripts/zellij-seed-permissions.sh` with the plugin's scope list copied from `ZELLIJ_PLUGIN_PERMISSIONS`. The script writes to `~/.cache/zellij/permissions.kdl` keyed by `<prefix>/share/zellij/plugins/<name>`, adds missing scopes to an existing block, and leaves scopes approved by hand. `zjtabs` has no entry, as in `install.sh`.

If a plugin bump asks for new scopes, edit the scope list in that tool's `post_install`.

`zellij-newtab-plus` is installed and granted, but `config.kdl` and the layout never load it, and no `c` binding references it. CLAUDE.md says it powers the `c` binding in `tmux` mode, which the config doesn't show.

### zsh plugins

The three plugins publish tags but no GitHub Releases, and dfutil's `github` kind and script tools with a `repo` read only releases. Each is therefore a repo-less `script` tool whose install command embeds the tag, so a pin bump changes the recipe and triggers a reinstall. `scripts/install-zsh-plugin.sh` downloads the tag tarball, extracts it into the tool directory, and links it at `<prefix>/share/zsh/plugins/<name>`. For user scope that is `~/.local/share/zsh/plugins/<name>`, so `.zshrc` sources them unchanged.

### Bespoke installers

| `install.sh` function | dfutil tool | Kind | Notes |
| --- | --- | --- | --- |
| `install_node` | `node` | `script` | `scripts/install-node.sh` fetches the latest LTS from nodejs.org. The `nodejs/node` GitHub releases carry no binaries, so the `github` kind can't install it. dfutil links `node`, `npm`, and `npx` from the tool directory instead of merging trees into `~/.local` |
| `install_claude` | `claude` | `script` | Runs the official installer; the version command reads `claude --version` |
| `install_ccstatusline` | `ccstatusline` | `npm` | Pinned to `2.2.32`, requires `node` |
| `install_claude_swap` | `claude-swap` | `uv` | Links `cswap` and `claude-swap`, requires `uv` |
| `install_powershell` | `pwsh` | `github` | The release tarball unpacks into a versioned directory, and dfutil links `pwsh` from it |
| nvim | `nvim` | `github` | Links `bin/nvim` only. Neovim finds its runtime relative to the resolved executable path, so the `share/nvim/runtime` and `lib/nvim` copies `install.sh` makes should be unnecessary. This has not been run |
| yazi and `ya` | `yazi` | `github` | `post_install` runs `scripts/yazi-packages.sh` for the nine `ya pkg` packages |
| Nerd Font | `jetbrainsmono-nerd-font` | `script` | `when = { os = "linux", wsl = false }`; WSL gets the font from `windows-setup.ps1` |
| bat, eza, zsh-syntax-highlighting themes, `bat cache --build` | `catppuccin-themes` | `script` | Requires `bat`. Mocha only |
| nushell theme, empty `secrets.nu` | `nushell-extras` | `script` | In the `nushell` preset |
| `full-install` marker | `full-marker` | `script` | Creates `~/.local/state/dotfiles/full-install`, which nvim reads, and removes it on uninstall |
| Windows block | `windows-setup` | `script` | `when = { wsl = true }`; `scripts/windows-setup.sh` keeps the interop check, distro detection, and path conversion, then calls `windows-setup.ps1` |
| rustup bootstrap | `rustup` | `script` | In the `cargo` preset |
| `install_cargo_clean_all` | `cargo-clean-all` | `cargo` | `post_install` writes the systemd units through `scripts/cargo-clean-all-timer.sh`, and `uninstall` removes them |

### Packages

`[packages.*]` lists every package in `PACKAGES`, plus `nushell`. `yazi/.linkignore` is unchanged and still excludes the directories `ya pkg` manages.

## Templates and palettes

dfutil renders `*.tmpl` files with `{{ name }}` placeholders and drops the suffix on deploy. The rendered file lands in `~/.local/share/dfutil/rendered/` and the home path links to it. A `.linkignore` entry keeps the untemplated original out of the deploy.

`zellij/.config/zellij/config.kdl.tmpl` replaces:

- Four absolute home paths (`copy_command` and the three zjstatus command scripts) with `{{ home }}`. This removes the need for the `homepath` git filter for this file.
- The three `file:~/.local/share/zellij/plugins/` locations with `file:{{ prefix }}/share/zellij/plugins/`.
- Every hex color with `{{ palette.<name> }}`. All 69 colors in the file are exact Mocha values.

`starship/.config/starship.toml.tmpl` renders the 26 entries of the palette block from the active palette. The palette is renamed from `catppuccin_mocha` to `catppuccin`, since the block now follows the active flavor.

These files are deliberately not templated:

- `zellij/.config/zellij/themes/catppuccin_mm.kdl` holds tweaked values such as `#bb5471`.
- `alacritty/.config/alacritty/themes/catppuccin-mocha.toml` is a Mocha theme file imported by name, and Alacritty on Windows reads it through the NTFS link chain.
- `git/.gitconfig` mixes Mocha values with derived colors such as `#663f52`.
- `ripgrep/.config/ripgrep/ripgreprc` uses `0xRR,0xGG,0xBB`.
- `zsh/.zshenv` has an `FZF_DEFAULT_OPTS` color block, but `.zshenv` is sourced by every zsh invocation and a rendered link adds a moving part to it.
- The downloaded bat, eza, zsh-syntax-highlighting, and nushell themes are third-party files.

`dfutil palette set latte` recolors only the two templated files. Everything in the list above stays Mocha.

## Switching a machine to dfutil

Run `dfutil init --repo <repo-path> --preset base`, add the presets the machine needs, then `dfutil apply`. Deploying links files over the existing symlinks, and any real file in the way is backed up as `<target>.bak.<timestamp>`. Make these edits in the same change.

### zsh/.zshrc

Replace the four per-tool lines in the *Tool integrations* block with one line for the aggregate script:

```diff
 if [[ "$TERM" != "dumb" ]]; then
-  [[ -f ~/.local/share/zoxide/init.zsh ]] && source ~/.local/share/zoxide/init.zsh
-  [[ -f ~/.local/share/atuin/init.zsh ]] && source ~/.local/share/atuin/init.zsh
-  [[ -f ~/.cache/starship/init.zsh ]] && source ~/.cache/starship/init.zsh
-  [[ -f ~/.cache/carapace/init.zsh ]] && source ~/.cache/carapace/init.zsh
+  [[ -f ~/.local/share/dfutil/init/init.zsh ]] && source ~/.local/share/dfutil/init/init.zsh
 fi
```

dfutil sources the tools in name order: atuin, carapace, starship, zoxide. `.zshrc` currently loads zoxide, atuin, starship, carapace. Check that `Ctrl+R` and the prompt behave after the change.

The plugin lines (`~/.local/share/zsh/plugins/...`) and the theme line (`~/.config/zsh/themes/...`) need no edit, because the plugin links and the theme download land at the same paths.

### nushell/.config/nushell/config.nu

Needed only with the `nushell` preset. Replace the four `source` lines under *Tool integrations* (zoxide, atuin, starship, carapace) with one:

```nu
source ~/.local/share/dfutil/init/init.nu
```

The comments above each line go with them. The theme `source` line and the `secrets.nu` line in `env.nu` stay, and `nushell-extras` creates both files.

### Other files

- `CLAUDE.md`: the *Tool-init scripts*, *Config deployment*, *Zellij status bar and plugin loading*, and *Pinned-version checks* sections describe `install.sh` behavior. Update them when `install.sh` is retired.
- `.gitattributes` and `git-filters/`: keep them until the untemplated `zellij/.config/zellij/config.kdl` is deleted. After that, the `homepath` filter has nothing to act on.
- `zellij/.config/zellij/config.kdl` and `starship/.config/starship.toml` duplicate their `.tmpl` files and no longer deploy. Delete them in the commit that retires `install.sh`, or the two copies drift.

## Not ported

| Feature | Why |
| --- | --- |
| `bin` package | `install.sh`'s download target. dfutil links tools into `~/.local/bin` itself |
| `.versions`, `.versions-repos`, and the run log | dfutil records its own state under `~/.local/share/dfutil` |
| `--check-pins` and `--upgrade=<name>` | No dfutil equivalent. Bump a pin by editing `dfutil.toml` |
| Weekly bump PRs (`check-pinned-versions.yml`) | The workflow reads pins from `install.sh`, not `dfutil.toml`. The zsh plugin and `ccstatusline` pins, and the review notes about permission scopes and `installedVersion`, need a new workflow |
| `--cleanup` | dfutil uninstalls a tool when it leaves the selection. Pruning old Claude Code versions, removing `~/.cargo` and `~/.rustup` when `--cargo` is off, and uninstalling Mason LSPs have no equivalent |
| `--copy` and `--remove` | dfutil has its own deploy and uninstall commands |
| `--yubikey` | `pull_yubikey_ssh_key()` has no tool form. It stays in `install.sh` |
| `~/.ssh/sockets` creation and the `chmod 700 ~/.ssh` and `chmod 600 ~/.ssh/config` fixes | No hook runs outside a tool. Create the directory by hand or add a script tool |
| `mosh` through apt, the git-core PPA upgrade, and the zsh, git, and locale prerequisite checks | System package installs are a documented exception in `install.sh`. dfutil installs nothing system-wide in user scope |
| Re-smudging `config.kdl` through the `homepath` filter | Replaced by the template |
| Mason LSP uninstall for non-`--full` runs | The `full` preset sets the marker; leaving it only removes the marker |
| macOS | Dropped from `install.sh` as well |

## Gaps in dfutil

These limits shaped `dfutil.toml`. Each is a candidate dfutil feature.

- **No build-time dependency.** `requires` pulls its target into every selection, including prebuilt runs. The `cargo` preset can't order `rustup` ahead of the source builds of other tools without forcing rustup onto every host. Only `cargo-clean-all` requires it. On a host with no Rust toolchain, install `rustup` first, or run `dfutil apply` a second time. A `build_requires` field that applies only under `build = "source"` would fix this.
- **Missing assets invalidate the config.** A selected `github` tool with no asset for the current platform fails validation. The six tools without aarch64 builds need `when = { arch = "x86_64" }`, which also disables their source builds on aarch64. Skipping with a warning would match `install.sh`.
- **Tag-only repos can't be pinned.** Script tools with a `repo` read only GitHub Releases. The zsh plugins are repo-less script tools with the tag written into the install and version commands.
- **Script tools without a `repo` never see upstream updates.** `node` installs the latest LTS once and reinstalls only when its recipe changes.
- **Hooks only run for tools.** Work that isn't tied to a tool, such as the SSH directory permissions, needs a script tool.
- **Theme downloads follow upstream, not the palette.** `catppuccin-themes` always fetches Mocha.

## Validation

Both checks ran against scratch homes only, never the real home directory.

- A `base` home: `config validate`, `status`, `plan`, `deploy --dry-run`, and `deploy` all succeed. Every `github` tool resolves to its current upstream release, `config.kdl` renders with no leftover `__DOTFILES_HOME__`, and its paths point into the scratch home.
- A `base,claude,full,nushell,cargo` home: `config validate` and `plan` succeed. Switching to `latte` and redeploying re-renders both templated files with Latte values.
- `apply` was not run, so no install command, `post_install` hook, or init script has run. Only `zellij-seed-permissions.sh` was exercised, against a temporary cache directory: it creates a block, adds a missing scope, and does nothing on a repeat run.

## Background

`install.sh` is a roughly 2,800-line bash script that downloads, links, and records versions in one pass. dfutil separates the declarative manifest from the tool that applies it. The port leaves `install.sh` working until a machine is switched. The two keep separate state and both write to `~/.local/bin`, so run only one of them on a given machine.
