return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.env.CC = "gcc"
      require("nvim-treesitter.install").compilers = { "gcc", "clang" }
      opts.ensure_installed = opts.ensure_installed or {}
      -- Parsers for the user's languages give highlighting/folding/indent even
      -- where the LSP server can't be installed yet (no Node/pip/php/.NET). Dupes
      -- with LazyVim defaults are fine — treesitter dedups. (rust comes with the
      -- lang.rust extra; listed here anyway for completeness.)
      vim.list_extend(opts.ensure_installed, {
        "regex",
        "python", "php", "phpdoc", "html", "css", "scss",
        "bash", "rust", "powershell",
      })
      return opts
    end,
  },
}
