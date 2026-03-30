require("venv-selector").setup()
vim.keymap.set("n", "<leader>cv", "<cmd>VenvSelect<cr>", { desc = "Select Venv" })
