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
      codelenses = {
        generate = true,
        gc_details = true,
        test = true,
        tidy = true,
        upgrade_dependency = true,
      },
    },
  },
})

local servers = { "html", "cssls", "gopls" }
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers

-- The `hints`/`codelenses` settings above only make the server COMPUTE them;
-- the client side has to be switched on per buffer too. <leader>ih toggles
-- hints off again when they get noisy; <leader>cl runs the lens under cursor.
local lsp_extras = vim.api.nvim_create_augroup("user_lsp_extras", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
  group = lsp_extras,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end
    if client:supports_method "textDocument/inlayHint" then
      vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
    end
    if client:supports_method "textDocument/codeLens" then
      vim.lsp.codelens.refresh { bufnr = args.buf }
    end
  end,
})

-- Keep codelenses current as the buffer changes.
vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "BufWritePost" }, {
  group = lsp_extras,
  callback = function(args)
    if #vim.lsp.get_clients { bufnr = args.buf, method = "textDocument/codeLens" } > 0 then
      vim.lsp.codelens.refresh { bufnr = args.buf }
    end
  end,
})
