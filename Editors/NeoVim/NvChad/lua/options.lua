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
