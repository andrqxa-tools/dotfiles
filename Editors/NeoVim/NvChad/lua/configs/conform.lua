local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    -- goimports = gofmt + import management (falls back to gopls via lsp_fallback)
    go = { "goimports" },
  },

  format_on_save = {
    timeout_ms = 1000,
    lsp_fallback = true,
  },
}

return options
