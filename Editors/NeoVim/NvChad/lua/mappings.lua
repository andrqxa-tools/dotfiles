require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- vim-tmux-navigator: seamless C-h/j/k/l between nvim splits and tmux/psmux
-- panes. Set here (after nvchad.mappings, which runs last) so these win over
-- NvChad's default window-nav on the same keys. The plugin's own mappings are
-- disabled via g:tmux_navigator_no_mappings in plugins/init.lua.
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { desc = "window/tmux left" })
map("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { desc = "window/tmux down" })
map("n", "<C-k>", "<cmd>TmuxNavigateUp<CR>", { desc = "window/tmux up" })
map("n", "<C-l>", "<cmd>TmuxNavigateRight<CR>", { desc = "window/tmux right" })

-- Go debugging (nvim-dap / nvim-dap-go)
map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "DAP toggle breakpoint" })
map("n", "<leader>dc", function() require("dap").continue() end, { desc = "DAP continue" })
map("n", "<leader>do", function() require("dap").step_over() end, { desc = "DAP step over" })
map("n", "<leader>di", function() require("dap").step_into() end, { desc = "DAP step into" })
map("n", "<leader>dgt", function() require("dap-go").debug_test() end, { desc = "DAP debug Go test" })
map("n", "<leader>dgl", function() require("dap-go").debug_last() end, { desc = "DAP debug last Go test" })
map("n", "<leader>du", function() require("dapui").toggle() end, { desc = "DAP toggle UI" })

-- Neotest (in-buffer test running via gotestsum)
map("n", "<leader>tt", function() require("neotest").run.run() end, { desc = "Neotest run nearest" })
map("n", "<leader>tf", function() require("neotest").run.run(vim.fn.expand "%") end, { desc = "Neotest run file" })
map("n", "<leader>td", function() require("neotest").run.run { strategy = "dap" } end, { desc = "Neotest debug nearest" })
map("n", "<leader>ts", function() require("neotest").summary.toggle() end, { desc = "Neotest summary" })
map("n", "<leader>to", function() require("neotest").output.open { enter = true } end, { desc = "Neotest output" })

-- LSP extras (gopls: inlay hints are enabled on attach in configs/lspconfig.lua)
map("n", "<leader>ih", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = 0 }, { bufnr = 0 })
end, { desc = "LSP toggle inlay hints" })
map("n", "<leader>cl", vim.lsp.codelens.run, { desc = "LSP run codelens" })

-- Diffview (clickable changed-files tree, side-by-side diffs)
map("n", "<leader>gd", function()
  if require("diffview.lib").get_current_view() then
    vim.cmd "DiffviewClose"
  else
    vim.cmd "DiffviewOpen"
  end
end, { desc = "Diffview toggle (working tree vs HEAD)" })
map("n", "<leader>gf", "<cmd>DiffviewFileHistory %<CR>", { desc = "Diffview current file history" })

-- Gopher (struct tags / if-err / impl)
map("n", "<leader>gsj", "<cmd>GoTagAdd json<CR>", { desc = "Gopher add json tags" })
map("n", "<leader>gsy", "<cmd>GoTagAdd yaml<CR>", { desc = "Gopher add yaml tags" })
map("n", "<leader>gie", "<cmd>GoIfErr<CR>", { desc = "Gopher if err" })
