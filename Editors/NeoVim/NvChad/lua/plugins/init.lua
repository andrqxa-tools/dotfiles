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
      {
        "leoluz/nvim-dap-go",
        opts = {
          -- Extra entry in the :DapContinue picker: attach to a service
          -- already running under headless delve in a neighbouring pane:
          --   dlv debug --headless --listen=127.0.0.1:38697 --accept-multiclient .
          -- dap-go connects to the given host:port instead of spawning dlv.
          dap_configurations = {
            {
              type = "go",
              name = "Attach to headless dlv (127.0.0.1:38697)",
              mode = "remote",
              request = "attach",
              host = "127.0.0.1",
              port = 38697,
            },
          },
        },
      },
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" }, opts = {} },
    },
    config = function()
      -- dap-ui opens/closes with the debug session; <leader>du toggles it manually.
      local dap, dapui = require "dap", require "dapui"
      dap.listeners.after.event_initialized["dapui"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui"] = function()
        dapui.close()
      end
    end,
  },

  -- ── In-buffer test running (neotest + gotestsum) ──────────────────
  {
    "nvim-neotest/neotest",
    ft = "go",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "fredrikaverpil/neotest-golang",
    },
    config = function()
      require("neotest").setup {
        adapters = {
          require "neotest-golang" { runner = "gotestsum" },
        },
      }
    end,
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
