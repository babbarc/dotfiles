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
vim.keymap.set("n", "<leader>ghB", ":ToggleBlame virtual<Enter>", { silent = true, desc = "Toggle virtual blame" })
vim.keymap.set("n", "<leader>gd", function()
  require("fzf-lua").fzf_exec(
    -- 1) use --color=always so git embeds ANSI color codes in the log
    "git log  --branches --oneline --decorate --color=always --pretty=format:'%C(yellow)%h%C(reset) %C(cyan)%d%C(reset) %s'",
    {
      prompt = "Commits> ",
      fzf_opts = {
        -- enable true ANSI-color parsing
        ["--ansi"] = true,
        -- allow multi-select with TAB/SPACE
        ["--multi"] = true,
        -- show a preview pane on the right
        ["--preview"] = "git show --color=always {1}",
        -- make the preview take 60% of the width and wrap long lines
        ["--preview-window"] = "right:60%:wrap",
        -- (optional) nicer keybindings inside FZF
        ["--bind"] = "tab:toggle+down,shift-tab:toggle+up",
      },
      actions = {
        -- default action: DiffviewOpen between two commits
        ["default"] = function(selected)
          if #selected == 1 then
            local sha = selected[1]:match("^([a-f0-9]+)")
            if sha then
              -- Try diff against parent (special handling for root commit later)
              local has_parent = vim.fn.systemlist("git rev-list --parents -n 1 " .. sha)[1]
              if has_parent and has_parent:find(" ") then
                vim.cmd("DiffviewOpen " .. sha .. "^.." .. sha)
              else
                vim.cmd("DiffviewOpen " .. sha)
              end
            end
          elseif #selected == 2 then
            local sha1 = selected[1]:match("^([a-f0-9]+)")
            local sha2 = selected[2]:match("^([a-f0-9]+)")
            if sha1 and sha2 then
              vim.cmd("DiffviewOpen " .. sha2 .. ".." .. sha1)
            end
          else
            vim.notify("Select one or two commits maximum", vim.log.levels.ERROR)
          end
        end,
      },
    }
  )
end, { desc = "Diff two selected commits" })
