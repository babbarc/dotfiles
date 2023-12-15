-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "]<space>", "o<Esc>k", { silent = true, desc = "Add line below" })
vim.keymap.set("n", "[<space>", "O<Esc>j", { silent = true, desc = "Add line above" })
vim.keymap.set("n", "<space>cc", ":ColorizerToggle<Enter>", { silent = true, desc = "Colorizer toggle" })
