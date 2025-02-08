return {
  {
    "vhyrro/luarocks.nvim",
    priority = 1000,
    config = true,
  },
  {
    "nvim-neorg/neorg",
    dependencies = { "luarocks.nvim" },
    version = "*",
    -- config = true,
    config = function()
      require("neorg").setup({
        load = {
          ["core.defaults"] = {}, -- Loads default behaviour
          ["core.concealer"] = {}, -- Adds pretty icons to your documents
          ["core.ui.calendar"] = {},
          ["core.completion"] = { config = { engine = "nvim-cmp", name = "[Norg]" } },
          ["core.integrations.nvim-cmp"] = {},
          -- ["core.concealer"] = { config = { icon_preset = "diamond" } },
          ["core.esupports.metagen"] = { config = { type = "auto", update_date = true } },
          ["core.qol.toc"] = {},
          ["core.qol.todo_items"] = {},
          ["core.looking-glass"] = {},
          ["core.presenter"] = { config = { zen_mode = "zen-mode" } },
          ["core.export"] = {},
          ["core.export.markdown"] = { config = { extensions = "all" } },
          ["core.summary"] = {},
          ["core.tangle"] = { config = { report_on_empty = false } },
          ["core.keybinds"] = {
            config = {
              default_keybinds = false,
            },
          },
          ["core.dirman"] = { -- Manages Neorg workspaces
            config = {
              workspaces = {
                notes = "~/notes/notes",
                work = "~/notes/work",
              },
              default_workspace = "work",
            },
          },
        },
      })

      vim.keymap.set(
        "n",
        "<leader>Nn",
        "<Plug>(neorg.dirman.new-note)",
        { desc = "create a new .norg file to take notes in" }
      )

      vim.api.nvim_create_autocmd("Filetype", {
        pattern = "norg",
        callback = function()
          local wk = require("which-key")
          wk.add({
            { "<leader>N", group = "Neorg" },
            { "<leader>Nt", group = "tasks" },
          })
          vim.keymap.set(
            "i",
            "<C-d>",
            "<Plug>(neorg.promo.demote)",
            { buffer = true, desc = "demote an object recursively" }
          )
          vim.keymap.set(
            "i",
            "<C-t>",
            "<Plug>(neorg.promo.promote)",
            { buffer = true, desc = "promote an object recursively" }
          )
          vim.keymap.set(
            "i",
            "<M-CR>",
            "<Plug>(neorg.itero.next-iteration)",
            { buffer = true, desc = "create an iteration of e.g. a list item" }
          )
          vim.keymap.set(
            "i",
            "<M-d>",
            "<Plug>(neorg.tempus.insert-date.insert-mode)",
            { buffer = true, desc = "insert a link to a date at the current cursor position" }
          )

          vim.keymap.set(
            "n",
            "<C-Space>",
            "<Plug>(neorg.tempus.insert-date)",
            { buffer = true, desc = "switch the task under the cursor between a select few states" }
          )
          vim.keymap.set(
            "n",
            "<CR>",
            "<Plug>(neorg.tempus.insert-date)",
            { buffer = true, desc = "hop to the destination of the link under the cursor" }
          )
          vim.keymap.set(
            "n",
            "<leader>Ncm",
            "<Plug>(neorg.looking-glass.magnify-code-block)",
            { buffer = true, desc = "magnifies a code block to a separate buffer" }
          )
          vim.keymap.set(
            "n",
            "<leader>Nid",
            "<Plug>(neorg.tempus.insert-date)",
            { buffer = true, desc = "insert a link to a date at the given position" }
          )
          vim.keymap.set(
            "n",
            "<leader>Nli",
            "<Plug>(neorg.pivot.list.invert)",
            { buffer = true, desc = "invert all items in a list" }
          )
          vim.keymap.set(
            "n",
            "<leader>Nlt",
            "<Plug>(neorg.pivot.list.toggle)",
            { buffer = true, desc = "toggle a list from ordered <-> unordered" }
          )
          vim.keymap.set(
            "n",
            "<leader>Nta",
            "<Plug>(neorg.qol.todo-items.todo.task-ambiguous)",
            { buffer = true, desc = 'mark the task under the cursor as "ambiguous"' }
          )
          vim.keymap.set(
            "n",
            "<leader>Ntc",
            "<Plug>(neorg.qol.todo-items.todo.task-cancelled)",
            { buffer = true, desc = 'mark the task under the cursor as "cancelled"' }
          )
          vim.keymap.set("n", "<leader>Ntd", "<Plug>(neorg.qol.todo-items.todo.task-done)", { buffer = true })
          vim.keymap.set("n", "<leader>Nth", "<Plug>(neorg.qol.todo-items.todo.task-on-hold)", { buffer = true })
          vim.keymap.set("n", "<leader>Nti", "<Plug>(neorg.qol.todo-items.todo.task-important)", { buffer = true })
          vim.keymap.set("n", "<leader>Ntp", "<Plug>(neorg.qol.todo-items.todo.task-pending)", { buffer = true })
          vim.keymap.set("n", "<leader>Ntr", "<Plug>(neorg.qol.todo-items.todo.task-recurring)", { buffer = true })
          vim.keymap.set("n", "<leader>Ntu", "<Plug>(neorg.qol.todo-items.todo.task-undone)", { buffer = true })
          vim.keymap.set("n", "<M-CR>", "<Plug>(neorg.esupports.hop.hop-link.vsplit)", { buffer = true })
          vim.keymap.set("n", ">", "<Plug>(neorg.promo.promote)", { buffer = true })
          vim.keymap.set("n", ">>", "<Plug>(neorg.promo.promote.nexted)", { buffer = true })
          vim.keymap.set("n", "<", "<Plug>(neorg.promo.demote)", { buffer = true })
          vim.keymap.set("n", "<<", "<Plug>(neorg.promo.demote.nexted)", { buffer = true })

          vim.keymap.set("v", "<", "<Plug>(neorg.promo.demote.range)", { buffer = true })
          vim.keymap.set("v", ">", "<Plug>(neorg.promo.promote.range)", { buffer = true })
        end,
      })
    end,
  },
}
