-- minia2 Active Oberon language server.
-- Loaded automatically for oberon buffers; independent of NVChad.

-- (a) tree-sitter highlighting, from the grammar in minia2's `editors/tree-sitter`
--     (install it with `editors/tree-sitter/install-nvim.sh`). nvim-treesitter is not
--     involved: it installs parsers, it does not run them. Silent when the parser is
--     not installed, so this config still works on a machine without it.
pcall(vim.treesitter.start)

-- (b) show the FULL diagnostic text inline, on lines under the cursor's line.
--     NOTE: vim.diagnostic.config is global — this affects all filetypes once an
--     oberon buffer is opened. Drop this line if you don't want that.
vim.diagnostic.config({ virtual_lines = { current_line = true } })

-- (c) live diagnostics: --live re-checks on every change; debounced 500ms so it
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

-- (d) folding from the server: procedures, records and objects, blocks, REPEAT/UNTIL,
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

local lsp_config = {
  name = "ob",
  cmd = cmd,
  root_dir = dir,
  init_options = init,
  flags = { debounce_text_changes = 500 },
}
local id = cmd and vim.lsp.start(lsp_config)

-- and if it was already attached before the autocommand existed at all
if id then fold_here(vim.lsp.get_client_by_id(id)) end

-- buffer-local LSP keymaps (guaranteed for .Mod even if the config manager's own
-- LSP maps don't attach to this client)
local o = { buffer = true, silent = true }
local function oberon_hover()
  -- Neovim's default hover is focusable: invoking it again moves the cursor into
  -- the popup. Keep this an informational overlay instead. A second gh closes it,
  -- and its default CursorMoved event closes it as soon as editing continues.
  local win = vim.b.lsp_floating_preview
  if type(win) == "number" and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    return
  end
  vim.lsp.buf.hover({ focusable = false, border = "rounded" })
end
vim.keymap.set("n", "gh", oberon_hover,
  { buffer = true, silent = true, desc = "Oberon: hover symbol" })
vim.keymap.set("n", "gd", vim.lsp.buf.definition, o)  -- go to definition
-- (also <C-]> via nvim's built-in LSP tagfunc)
-- Keep the documented actions local to Oberon buffers. NvChad's defaults have
-- changed over time, and its LspAttach hook is not guaranteed to see a client
-- started directly by this ftplugin.
vim.keymap.set("n", "<leader>ra", vim.lsp.buf.rename,
  { buffer = true, silent = true, desc = "Oberon: rename symbol" })
vim.keymap.set({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action,
  { buffer = true, silent = true, desc = "Oberon: code action" })
vim.keymap.set("n", "<leader>df", function()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  if #vim.diagnostic.get(0, { lnum = line }) == 0 then
    vim.notify("Oberon: no diagnostics on this line", vim.log.levels.INFO)
    return
  end
  vim.diagnostic.open_float(0, { scope = "line" })
end, { buffer = true, silent = true, desc = "Oberon: diagnostic on current line" })
-- (e) the two semantic-token modifiers the server sends: `dangerous` for everything of
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

-- :ObRestart -- restart the server after `task update` puts a new `ob` in place. Neovim 0.12's
-- built-in `:lsp restart` preserves every attached buffer. If the old command already stopped
-- the client (or it died), start it again from this buffer's config instead: merely doing `:edit`
-- does not reload an already-applied ftplugin and therefore cannot start anything.
vim.api.nvim_buf_create_user_command(0, "ObRestart", function()
  if #vim.lsp.get_clients { name = "ob" } > 0 then
    vim.cmd "lsp restart ob"
    vim.notify("ob: server restarting", vim.log.levels.INFO)
  elseif cmd then
    local new_id = vim.lsp.start(lsp_config, { bufnr = 0 })
    if new_id then
      fold_here(vim.lsp.get_client_by_id(new_id))
      vim.notify("ob: server started", vim.log.levels.INFO)
    end
  else
    vim.notify("ob: no executable language server configured", vim.log.levels.WARN)
  end
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

-- gy: where the TYPE of the name under the cursor is declared -- the jump gd cannot make, since
-- on a variable it answers the variable. `gy` is what coc and telescope use for it.
vim.keymap.set("n", "gy", vim.lsp.buf.type_definition,
  { buffer = true, silent = true, desc = "Oberon: go to type definition" })

-- gS: the project's symbols by name, which is the one navigation Neovim has no default key for.
-- Telescope's dynamic picker sends a new query per keystroke and the server re-parses the project
-- per query, so the plain prompt -- one query, one answer -- is the kinder of the two here.
vim.keymap.set("n", "gS", function()
  vim.ui.input({ prompt = "Oberon symbol: " }, function(query)
    if query and query ~= "" then vim.lsp.buf.workspace_symbol(query) end
  end)
end, { buffer = true, silent = true, desc = "Oberon: find a symbol in the project" })

-- gi: what extends the type under the cursor, or what overrides the method. Neovim 0.11+ has
-- `gri` for this out of the box; `gi` is here to sit next to gd/gr/gy rather than under `gr`.
vim.keymap.set("n", "gi", vim.lsp.buf.implementation,
  { buffer = true, silent = true, desc = "Oberon: go to implementation" })

-- documentHighlight is a request, not a mode: the server offers it and nothing asks unless
-- something is wired to ask. One CursorHold to request, one CursorMoved to clear, both
-- buffer-local. If nothing lights up, the colourscheme has no LspReferenceText/Read/Write --
-- `:hi LspReferenceText` says so, and that is a theme setting, not a server one.
local ob_highlight = vim.api.nvim_create_augroup("OberonDocumentHighlight", { clear = false })
vim.api.nvim_clear_autocmds({ group = ob_highlight, buffer = 0 })
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  group = ob_highlight, buffer = 0,
  callback = function() pcall(vim.lsp.buf.document_highlight) end,
})
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertLeave" }, {
  group = ob_highlight, buffer = 0,
  callback = function() pcall(vim.lsp.buf.clear_references) end,
})

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

-- <leader>rt / <leader>rT: the {TEST} procedures of this module, all of them or just the one the
-- cursor is in. This one DOES use an errorformat, unlike rr/rb above: `ob test` reports a failing
-- harvested test a second time as `<file>:<line>: FAIL <Module>.<Proc>`, so the quickfix list
-- lands on the failing test's declaration and nothing has to be written per editor. Everything
-- else ob prints is dropped by the format, or a green run would fill the list with "ok" lines.
--
-- The line is the declaration, not the failing statement: a trap prints a code offset after the
-- procedure name, and there is no line table to turn one into a line. The trap itself is in the
-- run's output, which is why the summary is echoed either way.
-- The second half, `%-G%.%#`, is not decoration: without a discard rule every other line of the
-- run becomes a fileless quickfix entry, and the list is the whole transcript.
local obtest_efm = "%f:%l: FAIL %m,%-G%.%#"

-- The {TEST} procedure the cursor is in: the nearest one at or above it. `<cword>` would only do
-- with the cursor on the name itself, and the point is to run the test being edited.
local function oberon_test_above()
  local at = vim.fn.search([[PROCEDURE\s*{TEST}]], "bcnW")
  if at == 0 then return nil end
  local name = vim.fn.matchstr(vim.fn.getline(at), [[{TEST}\s*\zs\w\+]])
  if name == "" then return nil end
  return name
end

local function oberon_run_tests(one)
  local command = obrun .. " test " .. vim.fn.shellescape(vim.fn.expand("%:p"))
  if one then
    local name = oberon_test_above()
    if not name then
      vim.notify("no {TEST} procedure at or above the cursor", vim.log.levels.WARN)
      return
    end
    command = command .. " -r " .. vim.fn.shellescape(name)
  end
  local output = vim.fn.systemlist(command)
  vim.fn.setqflist({}, " ", { title = "ob test", lines = output, efm = obtest_efm })
  local summary = ""
  for _, text in ipairs(output) do
    if text:match("^ob test: %d+ case") then summary = text end
  end
  if #vim.fn.getqflist() > 0 then
    vim.cmd("copen")
    vim.cmd("cfirst")
  else
    vim.cmd("cclose")
  end
  vim.notify(summary ~= "" and summary or (output[#output] or "ob test said nothing"))
end

vim.keymap.set("n", "<leader>rt", function() oberon_run_tests(false) end,
  { buffer = true, desc = "Oberon: run this module's {TEST} procedures" })
vim.keymap.set("n", "<leader>rT", function() oberon_run_tests(true) end,
  { buffer = true, desc = "Oberon: run the {TEST} procedure under the cursor" })
