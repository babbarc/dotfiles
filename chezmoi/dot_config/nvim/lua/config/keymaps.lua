-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set(
  "n",
  "]<space>",
  ':<C-u>call append(line("."),   repeat([""], v:count1))<CR>',
  { silent = true, desc = "Add line below" }
)
vim.keymap.set(
  "n",
  "[<space>",
  ':<C-u>call append(line(".")-1, repeat([""], v:count1))<CR>',
  { silent = true, desc = "Add line above" }
)
