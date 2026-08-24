-- Personal defaults for nvim-lint's markdownlint-cli2 linter (from LazyVim's
-- lang.markdown extra). `opts.linters` is LazyVim's own extension point for
-- overriding/extending individual linter definitions — see
-- lazyvim.plugins.linting for how it's merged in.
return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          -- Base linter args are just { "-" } (stdin). --config points at a
          -- fixed file next to this config (not baked in as a string — see
          -- the homepath git filter note in CLAUDE.md for why paths that can
          -- compute themselves at runtime should, rather than getting
          -- hardcoded) that turns off line-length (MD013) and
          -- first-line-must-be-h1 (MD041). Any project with its own
          -- .markdownlint.yaml / .markdownlint-cli2.yaml still layers on top
          -- of this and can re-enable either rule.
          args = { "-", "--config", vim.fn.stdpath("config") .. "/.markdownlint.yaml" },
        },
      },
    },
  },
}
