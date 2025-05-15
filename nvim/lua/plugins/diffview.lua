-- lua/plugins/snacks_git_diff.lua
return {
  {
    "folke/snacks.nvim",
    dependencies = { "sindrets/diffview.nvim" },
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          git_diff_any = {
            finder = function()
              -- run git‐log with unit‐separators so we can safe‐split out each piece
              local cmd = {
                "git",
                "log",
                "--branches",
                "--remotes",
                "--oneline",
                "--decorate=short",
                "--color=never",
                "--pretty=format:%h%x1f%D%x1f%s%x1f%ch",
              }
              local raw = vim.fn.systemlist(cmd)
              if vim.v.shell_error ~= 0 then
                vim.notify("Failed to load git log", vim.log.levels.ERROR)
                return {}
              end

              local items = {}
              for i, record in ipairs(raw) do
                if record ~= "" then
                  -- split on our unit‐separator
                  local parts = vim.split(record, "\x1f", { plain = true })
                  local sha = parts[1]
                  local decorate = parts[2]:gsub("^%s*(.-)%s*$", "%1") -- trim
                  local msg = parts[3]
                  local rel_date = parts[4]
                  -- rebuild a nice display string
                  local display = string.format("%s %s %s (%s)", sha, decorate ~= "" and decorate or "", msg, rel_date)

                  items[#items + 1] = {
                    idx = i, -- required
                    score = 0, -- required
                    text = display, -- shown in the list
                    commit = sha, -- for later Diffview use
                    branch = decorate,
                    msg = msg,
                    date = rel_date,
                  }
                end
              end

              return items
            end,

            format = function(item, picker)
              local util = Snacks.picker.util
              local hl = Snacks.picker.highlight
              local a = util.align
              local ret = {}

              -- 1) Commit icon + SHA
              ret[#ret + 1] = { picker.opts.icons.git.commit, "SnacksPickerGitCommit" }
              ret[#ret + 1] = { a(item.commit, 8, { truncate = true }), "SnacksPickerGitCommit" }
              ret[#ret + 1] = { " " }

              -- 2) Relative date
              ret[#ret + 1] = { a(item.date, 16), "SnacksPickerGitDate" }
              ret[#ret + 1] = { " " }

              -- 3) Branch/Tag decorate info (if any)
              if item.branch and item.branch ~= "" then
                -- local truncated = a(item.branch, 20, { truncate = true })
                local truncated = item.branch
                ret[#ret + 1] = { "[" .. truncated .. "]", "SnacksPickerGitBranch" }
                ret[#ret + 1] = { " " }
              end

              -- 4) Conventional-commit parsing: type, scope, breaking, and body
              local msg = item.msg
              local typ, scope, breaking, body = msg:match("^(%S+)%s*(%b())(!?):%s*(.*)$")
              if not typ then
                typ, breaking, body = msg:match("^(%S+)(!?):%s*(.*)$")
              end

              local msg_hl = "SnacksPickerGitMsg"
              if typ and body then
                local dimmed = vim.tbl_contains({ "chore", "bot", "build", "ci", "style", "test" }, typ)
                msg_hl = dimmed and "SnacksPickerDimmed" or "SnacksPickerGitMsg"

                -- type
                local type_hl = breaking ~= "" and "SnacksPickerGitBreaking"
                  or dimmed and "SnacksPickerBold"
                  or "SnacksPickerGitType"
                ret[#ret + 1] = { typ, type_hl }

                -- scope
                if scope and scope ~= "" then
                  ret[#ret + 1] = { scope, "SnacksPickerGitScope" }
                end

                -- breaking "!"
                if breaking ~= "" then
                  ret[#ret + 1] = { "!", "SnacksPickerGitBreaking" }
                end

                -- delimiter
                ret[#ret + 1] = { ": ", "SnacksPickerDelim" }
                msg = body
              end

              -- 5) The rest of the message
              ret[#ret + 1] = { msg, msg_hl }

              -- 6) Markdown-style inline formatting & issue hyperlinked
              hl.markdown(ret)
              hl.highlight(ret, { ["#%d+"] = "SnacksPickerGitIssue" })

              return ret
            end,

            preview = "git_show",

            matcher = { fuzzy = true },
            sort = { fields = { "idx" } },

            title = "Select commits to diff",

            confirm = function(picker)
              local sel = picker:selected()
              picker:close()

              local function open_single(s)
                local parents = vim.fn.systemlist("git rev-list --parents -n 1 " .. s)[1] or ""
                if parents:find(" ") then
                  vim.cmd("DiffviewOpen " .. s .. "^.." .. s)
                else
                  vim.cmd("DiffviewOpen " .. s)
                end
              end

              if #sel == 1 then
                open_single(sel[1].commit)
              elseif #sel == 2 then
                vim.cmd("DiffviewOpen " .. sel[2].commit .. ".." .. sel[1].commit)
              else
                vim.notify("Select one or two commits maximum", vim.log.levels.ERROR)
              end
            end,
          },
        },
      },
    },

    keys = {
      {
        "<leader>gD",
        function()
          require("snacks").picker.git_diff_any()
        end,
        desc = "Snacks: Git Diff",
      },
    },
  },
  {
    "sindrets/diffview.nvim",
    opts = {},
  },
}
