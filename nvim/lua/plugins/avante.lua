return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    dependencies = {
      "stevearc/dressing.nvim",
    },
    opts = {
      provider = "groq",
      vendors = {
        groq = {
          __inherited_from = "openai",
          api_key_name = "groq api key",
          endpoint = "https://api.groq.com/openai/v1",
          model = "deepseek-r1-distill-llama-70b",
        },
      },
      hints = { enabled = true },
    },
    build = LazyVim.is_win() and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" or "make",
  },
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "ai" },
      },
    },
  },
}
