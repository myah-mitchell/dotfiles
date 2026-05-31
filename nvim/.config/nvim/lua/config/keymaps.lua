-- keymaps.lua — custom keybindings on top of LazyVim defaults
local map = vim.keymap.set

-- ── Better escape ────────────────────────────────────────────────────────────
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })
map("i", "kj", "<Esc>", { desc = "Exit insert mode" })

-- ── Window navigation (Ctrl+hjkl) ────────────────────────────────────────────
-- These are primarily handled by zellij-nav.nvim (see plugins/zellij-nav.lua),
-- which calls the Zellij CLI when at the edge of the Neovim window.

-- ── Split creation (mirrors Zellij prefix bindings) ──────────────────────────
map("n", "<leader>|", "<cmd>vsplit<cr>",  { desc = "Vertical split" })
map("n", "<leader>-", "<cmd>split<cr>",   { desc = "Horizontal split" })

-- ── Better up/down (visual line movement) ────────────────────────────────────
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Down" })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Up" })

-- ── Move lines ───────────────────────────────────────────────────────────────
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("i", "<A-j>", "<Esc><cmd>m .+1<cr>==gi", { desc = "Move line down" })
map("i", "<A-k>", "<Esc><cmd>m .-2<cr>==gi", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- ── Clipboard ────────────────────────────────────────────────────────────────
-- X to delete without yanking to clipboard
map({ "n", "v" }, "x", '"_x', { desc = "Delete without yank" })

-- ── Clear search highlight ────────────────────────────────────────────────────
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear highlight" })

-- ── Save ─────────────────────────────────────────────────────────────────────
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><Esc>", { desc = "Save file" })

-- ── Tab navigation ───────────────────────────────────────────────────────────
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>",     { desc = "Next buffer" })

-- ── Indenting in visual stays in visual ──────────────────────────────────────
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })
