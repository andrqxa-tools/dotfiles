return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre", -- format on save (see configs/conform.lua)
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- ── Go toolchain (installed via mason for portability; also picked up
  --    from $PATH if already present) ─────────────────────────────────
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "gopls",
        "delve",
        "goimports",
        "gofumpt",
        "gomodifytags",
        "impl",
      })
    end,
  },

  -- ── Go debugging ──────────────────────────────────────────────────
  {
    "mfussenegger/nvim-dap",
    ft = "go",
    dependencies = {
      { "leoluz/nvim-dap-go", opts = {} },
    },
  },

  -- ── Go helpers: struct tags, if-err, impl, tests ──────────────────
  {
    "olexsmir/gopher.nvim",
    ft = "go",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    opts = {},
    build = function()
      vim.cmd [[silent! GoInstallDeps]]
    end,
  },

  -- ── Seamless nvim <-> tmux/psmux pane navigation ──────────────────
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    init = function()
      vim.g.tmux_navigator_no_mappings = 1 -- keymaps are set in mappings.lua
    end,
  },
}
