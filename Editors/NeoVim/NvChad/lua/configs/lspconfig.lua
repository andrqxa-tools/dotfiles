require("nvchad.configs.lspconfig").defaults()

-- gopls tuning (Neovim 0.11 vim.lsp.config API).
vim.lsp.config("gopls", {
  settings = {
    gopls = {
      gofumpt = true,
      staticcheck = true,
      completeUnimported = true,
      usePlaceholders = true,
      analyses = {
        unusedparams = true,
        nilness = true,
        unusedwrite = true,
      },
      hints = {
        assignVariableTypes = true,
        constantValues = true,
        rangeVariableTypes = true,
      },
    },
  },
})

local servers = { "html", "cssls", "gopls" }
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers
