-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("v", "<S-k>", ":m '<-2<CR>gv=gv")
vim.keymap.set("v", "<S-j>", ":m '>+1<CR>gv=gv")
vim.keymap.set("n", "<leader>yy", "yyp", { desc = "Duplicate line below" })
vim.keymap.set("v", "<leader>yd", ":t'><CR>gv", { desc = "Duplicate selection below" })
vim.keymap.set("n", "<leader>mk", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("n", "<leader>mj", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("v", "<leader>mk", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("v", "<leader>mj", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
