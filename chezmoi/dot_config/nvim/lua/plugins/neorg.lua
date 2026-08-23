return {
  {
    "vhyrro/luarocks.nvim",
    enabled = false,
    priority = 1000,
    config = true,
  },
  {
    "nvim-neorg/neorg",
    enabled = false,
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
                gtd = "~/notes/gtd",
              },
              default_workspace = "gtd",
            },
          },
        },
      })

      local wk = require("which-key")
      wk.add({
        { "<leader>j", group = "neorg" },
      })
      vim.keymap.set("n", "<leader>jn", "<Plug>(neorg.dirman.new-note)", { noremap = true, desc = "new note" })
      vim.keymap.set("n", "<leader>ji", "<cmd>Neorg index<CR>", { noremap = true, desc = "open index" })
      vim.keymap.set("n", "<leader>jc", "<cmd>Neorg return<CR>", { noremap = true, desc = "close neorg" })
      vim.keymap.set("n", "<leader>jj", "<cmd>Neorg journal<CR>", { noremap = true, desc = "journal" })
      vim.keymap.set("n", "<leader>jw", ":Neorg workspace<Space>", { noremap = true, desc = "workspaces" })

      vim.api.nvim_create_autocmd({ "Filetype" }, {
        pattern = { "norg" },
        callback = function()
          wk.add({
            { "<leader>jt", group = "tasks" },
            { "<leader>jl", group = "lists" },
          })
          vim.keymap.set(
            "i",
            "<C-d>",
            "<Plug>(neorg.promo.demote)",
            { noremap = true, buffer = true, desc = "demote an object recursively" }
          )
          vim.keymap.set(
            "i",
            "<C-t>",
            "<Plug>(neorg.promo.promote)",
            { noremap = true, buffer = true, desc = "promote an object recursively" }
          )
          vim.keymap.set(
            "i",
            "<M-CR>",
            "<Plug>(neorg.itero.next-iteration)",
            { noremap = true, buffer = true, desc = "create an iteration of e.g. a list item" }
          )
          vim.keymap.set(
            "i",
            "<M-d>",
            "<Plug>(neorg.tempus.insert-date.insert-mode)",
            { noremap = true, buffer = true, desc = "insert date" }
          )

          vim.keymap.set(
            "n",
            "<C-Space>",
            "<Plug>(neorg.tempus.insert-date)",
            { noremap = true, buffer = true, desc = "switch the task under the cursor between a select few states" }
          )
          vim.keymap.set(
            "n",
            "<CR>",
            "<Plug>(neorg.esupports.hop.hop-link)",
            { noremap = true, buffer = true, desc = "hop to the destination of the link under the cursor" }
          )
          vim.keymap.set(
            "n",
            "<leader>jm",
            "<Plug>(neorg.looking-glass.magnify-code-block)",
            { buffer = true, desc = "code magnify" }
          )
          vim.keymap.set("n", "<leader>jd", "<Plug>(neorg.tempus.insert-date)", { buffer = true, desc = "insert date" })
          vim.keymap.set("n", "<leader>jli", "<Plug>(neorg.pivot.list.invert)", { buffer = true, desc = "list invert" })
          vim.keymap.set("n", "<leader>jlt", "<Plug>(neorg.pivot.list.toggle)", { buffer = true, desc = "list toggle" })
          vim.keymap.set(
            "n",
            "<leader>jta",
            "<Plug>(neorg.qol.todo-items.todo.task-ambiguous)",
            { buffer = true, desc = "mark task as ambiguous" }
          )
          vim.keymap.set(
            "n",
            "<leader>jtc",
            "<Plug>(neorg.qol.todo-items.todo.task-cancelled)",
            { buffer = true, desc = "mark task as cancelled" }
          )
          vim.keymap.set(
            "n",
            "<leader>jtd",
            "<Plug>(neorg.qol.todo-items.todo.task-done)",
            { buffer = true, desc = "mark task as done" }
          )
          vim.keymap.set(
            "n",
            "<leader>jth",
            "<Plug>(neorg.qol.todo-items.todo.task-on-hold)",
            { buffer = true, desc = "mark task as on hold" }
          )
          vim.keymap.set(
            "n",
            "<leader>jti",
            "<Plug>(neorg.qol.todo-items.todo.task-important)",
            { buffer = true, desc = "mark task as important" }
          )
          vim.keymap.set(
            "n",
            "<leader>jtp",
            "<Plug>(neorg.qol.todo-items.todo.task-pending)",
            { noremap = true, buffer = true, desc = "mark task as pending" }
          )
          -- vim.keymap.set(
          --   "n",
          --   "<leader>jtr",
          --   "<Plug>(neorg.qol.todo-items.todo.task-recurring)",
          --   { noremap = true, buffer = true, "mark task as recurring" }
          -- )
          -- vim.keymap.set(
          --   "n",
          --   "<leader>jtu",
          --   "<Plug>(neorg.qol.todo-items.todo.task-undone)",
          --   { noremap = true, buffer = true, "mark task as undone" }
          -- )
          vim.keymap.set(
            "n",
            "<M-CR>",
            "<Plug>(neorg.esupports.hop.hop-link.vsplit)",
            { noremap = true, buffer = true, desc = "open the destination in a vertical split" }
          )
          vim.keymap.set(
            "n",
            ">.",
            "<Plug>(neorg.promo.promote)",
            { noremap = true, buffer = true, desc = "promote an object non-recursively" }
          )
          vim.keymap.set(
            "n",
            ">>",
            "<Plug>(neorg.promo.promote.nested)",
            { noremap = true, buffer = true, desc = "promote an object recursively" }
          )
          vim.keymap.set(
            "n",
            "<,",
            "<Plug>(neorg.promo.demote)",
            { noremap = true, buffer = true, desc = "demote an object non-recursively" }
          )
          vim.keymap.set(
            "n",
            "<<",
            "<Plug>(neorg.promo.demote.nested)",
            { noremap = true, buffer = true, desc = "demote an object recursively" }
          )
          vim.keymap.set(
            "n",
            "<leader>jo",
            "<cmd>Neorg toc<CR>",
            { noremap = true, buffer = true, desc = "show table of contents" }
          )
          vim.keymap.set(
            "n",
            "<leader>jct",
            "<cmd>Neorg toggle-concealer<CR>",
            { noremap = true, buffer = true, desc = "toggle concealer" }
          )

          vim.keymap.set(
            "v",
            "<",
            "<Plug>(neorg.promo.demote.range)",
            { noremap = true, buffer = true, desc = "demote selected objects" }
          )
          vim.keymap.set(
            "v",
            ">",
            "<Plug>(neorg.promo.promote.range)",
            { noremap = true, buffer = true, desc = "promote selected objects" }
          )
        end,
      })
    end,
  },
}
