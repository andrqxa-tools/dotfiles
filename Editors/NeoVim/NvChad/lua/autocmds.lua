require "nvchad.autocmds"

local augroup = vim.api.nvim_create_augroup("user_autoread", { clear = true })

-- Re-check buffers against disk on focus / entering a buffer / idle, so edits
-- made by claude, codex, git, etc. show up automatically instead of a stale
-- buffer or a W12 warning. FocusGained fires across tmux panes because the
-- tmux config sets `focus-events on`.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermClose", "TermLeave" }, {
  group = augroup,
  callback = function()
    if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
      vim.cmd "checktime"
    end
  end,
})

-- Tell me when a buffer was reloaded because it changed underneath me.
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = augroup,
  callback = function()
    vim.notify("File changed on disk — buffer reloaded", vim.log.levels.WARN)
  end,
})
