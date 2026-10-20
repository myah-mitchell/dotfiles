# zellij-org/zellij

Repo-specific checks for contributions to [Zellij](https://github.com/zellij-org/zellij). Read alongside the generic checks in `../SKILL.md`; this file wins where they differ.

## Project facts

- Default branch is `main`. PRs are squash-merged, so the PR title becomes the commit subject on `main` (with `(#<pr>)` appended).
- The maintainer is Aram Drevekenin (`imsnif`). He often finishes a PR himself instead of requesting changes, which is the work these checks try to save him.
- `CONTRIBUTING.md` says the maintainers are overloaded: large projects need a check-in first (Discord or Matrix), minor fixes may wait a long time, and issue and PR descriptions should not be LLM-generated.
- Non-trivial fixes should have an issue to discuss first, linked from the PR.
- Errors: functions return `Result` with `.context()`; log with `.non_fatal()` instead of `log::error!`. See `docs/ERROR_HANDLING.md`.

## Commands

CI runs these (`.github/workflows/rust.yml`):

```bash
cargo xtask format --check
cargo xtask build
cargo xtask test
cargo xtask test --no-web
cargo xtask integration-test
cargo test -p xtask
cargo xtask assets --check
```

Regenerate protobuf output with `cargo x proto` after any `.proto` change.

Local setup on this machine (no cargo on `PATH`):

```bash
PATH=$(ls -d /nix/store/*-rust-default-1.95.0 | head -1)/bin:$PATH \
PROTOC=$(ls -d /nix/store/*protobuf*/bin/protoc | tail -1) \
cargo xtask test
```

In a worktree that shares `/opt/zellij/target`, `cargo xtask test` ends with build checks that read plugins from `<worktree>/target/wasm32-wasip1/debug` and ignore `CARGO_TARGET_DIR`. Symlink `target -> /opt/zellij/target` in the worktree for the run, then remove it. Default plugins (`default-plugins/*`) are separate crates: test them from their own directory with `--target x86_64-unknown-linux-gnu`.

## Checklist

### Base and history

- Rebased on `upstream/main` right before asking for review, and again if the PR waits. Other PRs land often and take the next free protobuf numbers (see below).
- The PR title reads as a conventional commit (`fix(scope): ...`, `feat(plugin-api): ...`), since it becomes the squash subject.

### Generated files

- A `.proto` change comes with regenerated `zellij-utils/assets/prost*/` output from `cargo x proto`.
- New `CommandName` values and `PluginCommand` payload tags in `plugin_command.proto` (and event numbers in `event.proto`) use the next free number on current `main`. Recheck after every rebase; a collision is a silent conflict the maintainer has to renumber.
- Don't rebuild the bundled wasm in `zellij-utils/assets/plugins/`. The maintainer does that himself before merge.

### Follow the existing pattern

- A plugin command that asks the server for information blocks and returns a typed result instead of firing a request and delivering the answer later as an event. Copy `get_pane_scrollback` (`zellij-tile/src/shim.rs`, `zellij-server/src/plugins/zellij_exports.rs`, `PaneScrollbackResponse`): a `bounded(1)` channel sent with the screen instruction, `recv_timeout`, and a `Result<T, SomethingError>` whose error enum names each failure (timeout, not found, too large, and so on).
- A new plugin API touches, at least: `zellij-utils/src/data.rs`, the `.proto` files and `plugin_api/*.rs` conversions, `zellij-tile/src/shim.rs`, `zellij_exports.rs` (including the permission check), `route.rs`, `errors.rs` context enums, and `PaneInfo` constructors in `kdl/mod.rs` if `PaneInfo` grew. Grep for an existing sibling variant across the workspace to find every match arm.
- Nested-session features work at any depth, not just one level. `NestedDepthThreeHarness` in `zellij-integration-tests/src/nested.rs` exists to test that.
- Request and reply protocols carry request ids, deadlines, and an explicit failure when the other side goes away, rather than "may never answer" in a doc comment.

### Integration audit

When adding or changing a pane state (hidden, collapsed, suppressed, fullscreen, stacked, and so on), check every path that already handles the existing states:

- Session serialization for resurrection (`Screen::get_layout_metadata`, `Tab::tiled_pane_serialization_geoms`). The saved layout must reload correctly while the pane is in the new state.
- Mouse hit-testing (`Tab::get_pane_id_at`).
- Focus and selectability (`focus_pane`, `move_clients_out_of_pane`, directional focus moves).
- Close paths (`remove_pane`, `fill_space_over_pane`, size constraints of neighbors).
- Resize and relayout, including after a close.
- `PaneInfo` for plugins (`data.rs`, `event.proto`, `event.rs`, and the session-info KDL in `kdl/mod.rs`), next to the sibling flags `is_fullscreen`, `is_floating`, `is_suppressed`.
- Every existing reader of any set or flag whose meaning the change widens (for example `panes_to_hide.contains`).
- Plugin event delivery for panes in the state (mode, tab, and pane updates still reach them).

When changing how config is written back (`zellij-utils/src/input/config_file_edit.rs`), check every producer of the `ConfigEdit` variant, every reader of the written file, and the read-back verification.

### Tests

Test at the tiers the analog uses. For server and plugin API work that usually means all of:

- `zellij-server/src/unit/screen_tests.rs` for screen instructions, including each error arm.
- `zellij-server/src/tab/unit/tab_tests.rs` for pane and layout behavior, one test per integration point above.
- `zellij-server/src/plugins/unit/plugin_tests.rs` with support added to `default-plugins/fixture-plugin-for-tests` for a new plugin command or event.
- `zellij-integration-tests` for whole-app and nested-session behavior, including depth three for nesting.

### Style

- Terse code. Short or no doc comments on new functions and variants; the maintainer trims long ones.
- American spelling in comments, commit messages, and identifiers ("behavior", "recognize").
- `CHANGELOG.md`: one line at the end of `## [Unreleased]`, in the form `* <type>: <4 to 12 words> (https://github.com/zellij-org/zellij/pull/<pr>)`. Link the PR, not the issue. No explanation clauses.

### PR readiness

- Tick "Allow edits by maintainers" when opening the PR. He finishes PRs himself and can't push without it.
- Write the description yourself, briefly.

## Maintainer preferences

- He makes design changes himself when he sees a better protocol (pull with a generation counter instead of push, following focus to the deepest nested session) and explains them in a short PR comment. Expect that on new protocols; it isn't a sign the PR failed.
- He takes counter-arguments seriously when they come with concrete examples: on #5590 he dropped his `suppressed_panes` suggestion for the contributor's approach after examples, then proposed the `PanesToHide` structure.
- He favors short CHANGELOG lines and trims explanation from them.
- Small, self-contained fixes with tests (like #5680) merge unchanged.
- Several small fixes to the same screen or code path can share one PR, one commit each, with a note offering to split them. #5729 bundled three and merged unchanged.
- A `CHANGELOG.md` conflict from other PRs landing in `## [Unreleased]` is expected; he resolves it with a merge of `main` before squashing. It isn't a reason to rebase on its own.
- He merges past CI failures he recognizes as unrelated flaky tests, and fixes those separately.

## Reviewed PRs

| PR | Merged | Lessons added |
| --- | --- | --- |
| [#5589](https://github.com/zellij-org/zellij/pull/5589) | 2026-09-24 | Rebase before review; protobuf number collisions; blocking plugin command with typed errors; any-depth nesting; request ids and failure arms; screen, plugin, and fixture tests; terse comments; American spelling; short CHANGELOG |
| [#5590](https://github.com/zellij-org/zellij/pull/5590) | 2026-10-06 | Pane-state integration audit (serialization, hit-testing, focus, close, `PaneInfo`); tab tests per integration point; allow maintainer edits; wasm rebuild is his step |
| [#5680](https://github.com/zellij-org/zellij/pull/5680) | 2026-10-05 | None; merged unchanged, CHANGELOG line kept as written |
| [#5729](https://github.com/zellij-org/zellij/pull/5729) | 2026-10-19 | None to the checklist; merged unchanged. Preferences: related fixes may share a PR, CHANGELOG conflicts are his to merge, unrelated flaky CI doesn't block |
