-- autocmds.lua — custom autocommands

local function augroup(name)
  return vim.api.nvim_create_augroup("dotfiles_" .. name, { clear = true })
end

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group    = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank({ higroup = "Visual", timeout = 150 })
  end,
})

-- Resize splits when window is resized
vim.api.nvim_create_autocmd("VimResized", {
  group    = augroup("resize_splits"),
  callback = function() vim.cmd("tabdo wincmd =") end,
})

-- Go to last edit position when opening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  group    = augroup("last_loc"),
  callback = function(event)
    local exclude = { "gitcommit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) then return end
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Auto-close some filetypes with q
vim.api.nvim_create_autocmd("FileType", {
  group   = augroup("close_with_q"),
  pattern = {
    "PlenaryTestPopup", "help", "lspinfo", "man", "notify", "qf",
    "query", "spectre_panel", "startuptime", "tsplayground",
    "neotest-output", "checkhealth", "neotest-summary", "neotest-output-panel",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Wrap and spell in text filetypes
vim.api.nvim_create_autocmd("FileType", {
  group   = augroup("wrap_spell"),
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap  = true
    vim.opt_local.spell = true
  end,
})

-- WSL2 clipboard — OSC52 passthrough via Alacritty
if vim.fn.has("wsl") == 1 then
  vim.g.clipboard = {
    name  = "WslClipboard",
    -- routes through clip-clean.py (see zellij/scripts) instead of clip.exe directly,
    -- so yanked Nerd Font icons don't turn into tofu boxes when pasted elsewhere
    copy  = { ["+"] = "/home/m0rsla/.config/zellij/scripts/clip-clean.py", ["*"] = "/home/m0rsla/.config/zellij/scripts/clip-clean.py" },
    paste = {
      ["+"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
      ["*"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    },
    cache_enabled = 0,
  }
end
