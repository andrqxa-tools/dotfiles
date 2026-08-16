-- minia2 Active Oberon language server.
-- Loaded automatically for oberon buffers; independent of NVChad.

-- (a) show the FULL diagnostic text inline, on lines under the cursor's line.
--     NOTE: vim.diagnostic.config is global — this affects all filetypes once an
--     oberon buffer is opened. Drop this line if you don't want that.
vim.diagnostic.config({ virtual_lines = { current_line = true } })

-- (b) live diagnostics: --live re-checks on every change; debounced 500ms so it
--     updates after you pause typing instead of flickering. Drop "--live" (and
--     the flags line) to go back to on-open/on-save only.
local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0)) or vim.fn.getcwd()

local stdlib = vim.env.A2_STDLIB_SRC
local syms = vim.env.A2_SYMS

-- How the server is started. The tarball SDK is preferred over the image: it is the
-- documented entrance, it starts in milliseconds instead of a container, and it is
-- whatever you last installed -- an image built a day ago does not have what you
-- added to the server today.
--   $A2_OB   -- explicit path to the tarball SDK's ob
--   ob       -- on PATH (sdk/install.sh puts it in ~/.local/bin)
--   docker   -- fallback, the published image
local cmd, init = nil, {}
local ob = vim.env.A2_OB
if (not ob or ob == "") and vim.fn.executable("ob") == 1 then
  ob = vim.fn.exepath("ob")
end

if ob and ob ~= "" and vim.fn.executable(ob) == 1 then
  -- native: the server reads the host paths itself, nothing to mount
  cmd = { ob, "lsp", "--live" }
  if stdlib and stdlib ~= "" then init.stdlibSrc = stdlib end
else
  -- the image: the file's directory is mounted at /work so the server can resolve
  -- (and build on demand) the project's own modules, not just the standard library
  cmd = { "docker", "run", "--rm", "-i", "-v", dir .. ":/work:ro" }
  if stdlib and stdlib ~= "" then
    vim.list_extend(cmd, { "-v", stdlib .. ":/libsrc:ro" })
    init.stdlibSrc = stdlib
  end
  if syms and syms ~= "" then
    vim.list_extend(cmd, { "-v", syms .. ":/psym:ro" })
  end
  vim.list_extend(cmd, { "minia2-sdk", "lsp", "--live" })
end

-- (c) folding from the server: procedures, records and objects, blocks, REPEAT/UNTIL,
--     the IMPORT list and multi-line comments. Turned on only when the client says it
--     can do it, so an older SDK (or the image) is left alone.
local function fold_here(client)
  if not client or not client:supports_method("textDocument/foldingRange") then return end
  local win = vim.api.nvim_get_current_win()
  vim.wo[win][0].foldmethod = "expr"
  vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
  -- a closed fold shows the first line it hides rather than a row of dashes
  vim.wo[win][0].foldtext = "v:lua.vim.lsp.foldtext()"
  -- open with everything unfolded; za / zc / zR / zM from there
  vim.wo[win][0].foldlevel = 99
  vim.wo[win][0].foldenable = true
end

-- registered BEFORE the client starts: when the server is already running (any .Mod
-- opened after the first) vim.lsp.start attaches synchronously, and an autocommand
-- created after it would never see the event.
vim.api.nvim_create_autocmd("LspAttach", {
  buffer = 0,
  callback = function(ev)
    fold_here(vim.lsp.get_client_by_id(ev.data.client_id))
  end,
})

local id = vim.lsp.start({
  name = "ob",
  cmd = cmd,
  root_dir = dir,
  init_options = init,
  flags = { debounce_text_changes = 500 },
})

-- and if it was already attached before the autocommand existed at all
if id then fold_here(vim.lsp.get_client_by_id(id)) end

-- buffer-local LSP keymaps (guaranteed for .Mod even if the config manager's own
-- LSP maps don't attach to this client)
local o = { buffer = true, silent = true }
vim.keymap.set("n", "K",  vim.lsp.buf.hover, o)       -- hover: type + doc
vim.keymap.set("n", "gd", vim.lsp.buf.definition, o)  -- go to definition
-- (also <C-]> via nvim's built-in LSP tagfunc)
-- Ctrl-Click: move the cursor to the click position, then go to definition
vim.keymap.set("n", "<C-LeftMouse>", "<LeftMouse><Cmd>lua vim.lsp.buf.definition()<CR>", o)

-- Commands rather than mappings: zi, zC and the rest of the z-family already mean
-- something in vim, and folding a kind is rare enough not to be worth taking one.
vim.api.nvim_buf_create_user_command(0, "ObFoldImports", function()
  vim.lsp.foldclose("imports", vim.api.nvim_get_current_win())
end, { desc = "Oberon: close the IMPORT folds" })

vim.api.nvim_buf_create_user_command(0, "ObFoldComments", function()
  vim.lsp.foldclose("comment", vim.api.nvim_get_current_win())
end, { desc = "Oberon: close the comment folds" })

-- g0: module outline (document symbols). Telescope picker if available, else loclist.
vim.keymap.set("n", "g0", function()
  local ok, tb = pcall(require, "telescope.builtin")
  if ok and tb.lsp_document_symbols then
    tb.lsp_document_symbols()  -- opens in insert (type to filter); Esc for j/k navigation
  else
    vim.lsp.buf.document_symbol()
  end
end, { buffer = true, silent = true, desc = "Oberon: outline (document symbols)" })  -- g0

-- gr: find references (Telescope picker if available, else quickfix). Project-wide
-- for module-level symbols — can take a few seconds on a large tree.
vim.keymap.set("n", "gr", function()
  local ok, tb = pcall(require, "telescope.builtin")
  if ok and tb.lsp_references then
    tb.lsp_references()
  else
    vim.lsp.buf.references()
  end
end, { buffer = true, silent = true, desc = "Oberon: find references" })
-- rename is NVChad's existing <leader>ra (vim.lsp.buf.rename) — attaches to our client too
