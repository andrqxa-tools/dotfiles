require "nvchad.options"

local o = vim.o

-- Share yanks with the system clipboard — paste straight into claude/codex
-- (and their output back into nvim). Key for the tmux + AI-CLI workflow.
o.clipboard = "unnamedplus"

-- Snappier CursorHold so the auto-reload autocmd (see autocmds.lua) fires
-- quickly when an external tool changes a file on disk.
o.updatetime = 300

-- Pick up files changed on disk (by claude/codex, git, formatters, ...).
o.autoread = true

-- Normal-mode commands on Cyrillic layouts (RU/UA): langmap translates each
-- key to its QWERTY equivalent, so hjkl / dd / ciw / gd / u / p etc. work
-- without switching back to English. Insert mode is untouched — Cyrillic
-- types as usual. Only BUILT-IN commands are translated: <leader>-mappings
-- and multi-key plugin combos still expect the English layout ('langremap'
-- stays off — turning it on causes double-translation bugs in plugins).
vim.opt.langmap = {
  -- Russian ЙЦУКЕН, full rows incl. punctuation keys
  -- (х→[ ъ→] ж→; э→' б→, ю→. ё→`; Ж→: enters command-line mode)
  [[ёйцукенгшщзхъфывапролджэячсмитьбю;`qwertyuiop[]asdfghjkl\;'zxcvbnm\,.]],
  [[ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ;~QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>]],
  -- Ukrainian-only keys (і ї є ґ sit where Russian has ы ъ э ё)
  [[іІїЇєЄґҐ;sS]}'"`~]],
}
