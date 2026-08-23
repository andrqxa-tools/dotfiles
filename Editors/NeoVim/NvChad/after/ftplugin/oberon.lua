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
elseif vim.fn.executable("docker") == 0 then
  -- No ob and no docker: say which, because the alternative is nvim reporting that a
  -- container runtime is missing on a phone, which sends the reader after the wrong thing.
  -- Seen for real: $A2_OB held a path with a typo, so `ob` was "not executable" and the
  -- error that surfaced was about docker.
  vim.notify(
    ("A2: no language server. $A2_OB = %s, and no `ob` on PATH."):format(
      (ob and ob ~= "") and ob or "(unset)"),
    vim.log.levels.WARN)
  cmd = nil
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

local id = cmd and vim.lsp.start({
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
-- (d) the two semantic-token modifiers the server sends: `dangerous` for everything of
--     SYSTEM (GET, PUT, MOVE, VAL, ADR, the registers) and for HALT, UNTRACED, UNTRACKED,
--     UNCHECKED, UNCOOPERATIVE, UNSAFE; `checks` for ASSERT. What they mark is where the
--     program stops being a checked program, which is the one thing A2's own editor
--     colours that is worth having here. Neovim has no default for a modifier it has not
--     heard of, so without these two lines the server's answer is simply invisible.
--     Set once, not per buffer: a highlight group is global. :Inspect on a word says which
--     groups it got, which is how to tell "not coloured" from "not sent".
--
--     On the colours: a foreground red does NOT work here. This theme spends #e06c75 on
--     Statement and Identifier -- and therefore on IMPORT, CONST, VAR and every plain
--     identifier -- so a red SYSTEM lands in the middle of a page that is already red and
--     marks nothing. What it needs is the axis the palette leaves free, and that is the
--     background: #e06c75 red, #c678dd purple, #e5c07b yellow, #98c379 green and #61afef
--     blue are all taken, backgrounds are not. So `dangerous` is a dark maroon wash under
--     a near-white word, which also says the right thing -- it marks a REGION where the
--     language stopped being checked, not a word that happens to be a keyword. `checks` is
--     cyan, the one hue nothing else in this theme uses.
local function oberon_token_colours()
  vim.api.nvim_set_hl(0, "@lsp.mod.dangerous.oberon", { fg = "#ffd9d0", bg = "#5c1f26", bold = true })
  vim.api.nvim_set_hl(0, "@lsp.mod.checks.oberon", { fg = "#2bbac5", bold = true })
end

--     Set on every .Mod that opens, not once behind a flag: nvim_set_hl is cheap, and a flag
--     meant that editing these two lines did nothing until the whole editor was restarted.
oberon_token_colours()
-- a colourscheme change clears highlight groups, so put them back after one
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("OberonTokenHl", { clear = true }),
  callback = oberon_token_colours,
})

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

-- :ObRestart -- stop the server and let it come back on the next attach. There is no
-- :LspRestart to reach for: nvim-lspconfig 2.x dropped its Lsp* commands, and this client is
-- started by this file with vim.lsp.start rather than by lspconfig, so nothing would register
-- one anyway. Needed after `task update` puts a new `ob` in place; NOT needed for a colour
-- change, which is client-side and takes effect on :e.
vim.api.nvim_buf_create_user_command(0, "ObRestart", function()
  local bufs = {}
  for _, c in ipairs(vim.lsp.get_clients { name = "ob" }) do
    for b in pairs(c.attached_buffers or {}) do
      if vim.api.nvim_buf_is_loaded(b) then bufs[#bufs + 1] = b end
    end
    c:stop(true)   -- vim.lsp.stop_client is deprecated in 0.12
  end
  -- re-running the ftplugin is what starts the client again
  vim.schedule(function()
    for _, b in ipairs(#bufs > 0 and bufs or { vim.api.nvim_get_current_buf() }) do
      vim.api.nvim_buf_call(b, function() vim.cmd "edit" end)
    end
    vim.notify("ob: server restarted", vim.log.levels.INFO)
  end)
end, { desc = "Oberon: restart the language server" })

-- gO: the outline as a side panel, which is what PET's Program Structure panel is. g0 above
-- goes through Telescope, and a picker flattens the tree and sorts it by name -- so the
-- IMPORT group, the nesting and the source order the server took trouble to send are only
-- visible here. Falls back to g0's behaviour if the plugin is not installed.
vim.keymap.set("n", "gO", function()
  if pcall(require, "outline") then
    vim.cmd "Outline!"  -- ! keeps the cursor in the code window
  else
    vim.lsp.buf.document_symbol()
  end
end, { buffer = true, silent = true, desc = "Oberon: outline panel" })

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

-- <leader>rr / <leader>rb: compile and run, or just compile. `ob` finds its own runtime, so
-- no A2SDK here. No errorformat/quickfix on purpose — the server already reports compile
-- errors in the buffer, and a second channel for the same diagnostics is noise.
--
-- The same `ob` the server above resolved ($A2_OB, else PATH), and $TMPDIR before /tmp: on a
-- phone under Termux there is no `ob` on PATH and no /tmp at all, so a mapping that spelled both
-- out did nothing and said nothing about why.
local obrun = (ob and ob ~= "" and vim.fn.shellescape(ob)) or "ob"
local obtmp = vim.env.TMPDIR
if not obtmp or obtmp == "" then obtmp = "/tmp" end
vim.keymap.set("n", "<leader>rr", "<Cmd>!" .. obrun .. " run %<CR>",
  { buffer = true, desc = "Oberon: run this module" })
vim.keymap.set("n", "<leader>rb", "<Cmd>!" .. obrun .. " build % -o " .. obtmp .. "/%:t:r<CR>",
  { buffer = true, desc = "Oberon: build to $TMPDIR" })
