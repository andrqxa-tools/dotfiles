-- minia2 Active Oberon language server (diagnostics over LSP).
-- Loaded automatically for oberon buffers; independent of NVChad.

-- (a) show the FULL diagnostic text inline, on lines under the cursor's line.
--     NOTE: vim.diagnostic.config is global — this affects all filetypes once an
--     oberon buffer is opened. Drop this line if you don't want that.
vim.diagnostic.config({ virtual_lines = { current_line = true } })

-- (b) live diagnostics: --live re-checks on every change; debounced 500ms so it
--     updates after you pause typing instead of flickering. Drop "--live" (and
--     the flags line) to go back to on-open/on-save only.
local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0)) or vim.fn.getcwd()
vim.lsp.start({
  name = "ob",
  -- mount the file's directory at /work so the server can resolve (and build on
  -- demand) the project's own modules, not just the standard library
  cmd = { "docker", "run", "--rm", "-i", "-v", dir .. ":/work:ro", "minia2-sdk", "lsp", "--live" },
  root_dir = dir,
  flags = { debounce_text_changes = 500 },
})

-- buffer-local LSP keymaps (guaranteed for .Mod even if the config manager's own
-- LSP maps don't attach to this client)
local o = { buffer = true, silent = true }
vim.keymap.set("n", "K",  vim.lsp.buf.hover, o)       -- hover: type + doc
vim.keymap.set("n", "gd", vim.lsp.buf.definition, o)  -- go to definition
vim.keymap.set("n", "<C-k>", vim.lsp.buf.definition, o)  -- Ctrl-K: go to definition
-- Ctrl-Click: move the cursor to the click position, then go to definition
vim.keymap.set("n", "<C-LeftMouse>", "<LeftMouse><Cmd>lua vim.lsp.buf.definition()<CR>", o)
