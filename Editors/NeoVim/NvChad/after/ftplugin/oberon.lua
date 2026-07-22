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

-- mount the file's directory at /work so the server can resolve (and build on demand)
-- the project's own modules, not just the standard library. Go-to-definition then
-- jumps within the file and into sibling project modules.
local cmd = { "docker", "run", "--rm", "-i", "-v", dir .. ":/work:ro" }
local init = {}

-- optional: point A2_STDLIB_SRC at a full A2 source tree, e.g.
--   export A2_STDLIB_SRC=$HOME/Projects/A2/a2oberon/source
-- so go-to-definition also reaches standard-library modules that aren't in the
-- current project. (When you're editing inside that tree already, every module is a
-- sibling in /work, so stdlib jumps work without this.)
local stdlib = vim.env.A2_STDLIB_SRC
if stdlib and stdlib ~= "" then
  vim.list_extend(cmd, { "-v", stdlib .. ":/libsrc:ro" })
  init.stdlibSrc = stdlib
end
vim.list_extend(cmd, { "minia2-sdk", "lsp", "--live" })

vim.lsp.start({
  name = "ob",
  cmd = cmd,
  root_dir = dir,
  init_options = init,
  flags = { debounce_text_changes = 500 },
})

-- buffer-local LSP keymaps (guaranteed for .Mod even if the config manager's own
-- LSP maps don't attach to this client)
local o = { buffer = true, silent = true }
vim.keymap.set("n", "K",  vim.lsp.buf.hover, o)       -- hover: type + doc
vim.keymap.set("n", "gd", vim.lsp.buf.definition, o)  -- go to definition
-- (also <C-]> via nvim's built-in LSP tagfunc)
-- Ctrl-Click: move the cursor to the click position, then go to definition
vim.keymap.set("n", "<C-LeftMouse>", "<LeftMouse><Cmd>lua vim.lsp.buf.definition()<CR>", o)

-- g0: module outline (document symbols). Telescope picker if available, else loclist.
vim.keymap.set("n", "g0", function()
  local ok, tb = pcall(require, "telescope.builtin")
  if ok and tb.lsp_document_symbols then
    tb.lsp_document_symbols()  -- opens in insert (type to filter); Esc for j/k navigation
  else
    vim.lsp.buf.document_symbol()
  end
end, { buffer = true, silent = true, desc = "Oberon: outline (document symbols)" })  -- g0
