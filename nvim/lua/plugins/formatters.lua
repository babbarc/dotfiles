return {
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      table.insert(opts.ensure_installed, "bash-language-server")
      table.insert(opts.ensure_installed, "clangd")
      table.insert(opts.ensure_installed, "codelldb")
      table.insert(opts.ensure_installed, "eslint_d")
      table.insert(opts.ensure_installed, "eslint-lsp")
      table.insert(opts.ensure_installed, "json-lsp")
      table.insert(opts.ensure_installed, "latexindent")
      table.insert(opts.ensure_installed, "lua-language-server")
      table.insert(opts.ensure_installed, "neocmakelsp")
      table.insert(opts.ensure_installed, "prettierd")
      table.insert(opts.ensure_installed, "shellcheck")
      table.insert(opts.ensure_installed, "shfmt")
      table.insert(opts.ensure_installed, "stylua")
      table.insert(opts.ensure_installed, "tailwindcss-language-server")
      table.insert(opts.ensure_installed, "taplo")
      table.insert(opts.ensure_installed, "texlab")
    end,
  },
  -- {
  --   "stevearc/conform.nvim",
  --   optional = true,
  --   opts = {
  --     formatters_by_ft = {
  --       ["javascript"] = { "prettierd" },
  --       ["javascriptreact"] = { "prettierd" },
  --       ["typescript"] = { "prettierd" },
  --       ["typescriptreact"] = { "prettierd" },
  --       ["vue"] = { "prettierd" },
  --       ["css"] = { "prettierd" },
  --       ["scss"] = { "prettierd" },
  --       ["less"] = { "prettierd" },
  --       ["html"] = { "prettierd" },
  --       ["json"] = { "prettierd" },
  --       ["jsonc"] = { "prettierd" },
  --       ["yaml"] = { "prettierd" },
  --       ["markdown"] = { "prettierd" },
  --       ["markdown.mdx"] = { "prettierd" },
  --       ["graphql"] = { "prettierd" },
  --       ["handlebars"] = { "prettierd" },
  --       ["python"] = { "black" },
  --     },
  --   },
  -- },
}
