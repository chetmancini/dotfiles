-- Ensure parsers are installed (async, won't block startup)
local ts = require("nvim-treesitter")

local desired_parsers = {
  "bash", "c", "css", "diff", "html", "javascript", "jsdoc", "json", "jsonc",
  "lua", "luadoc", "luap", "markdown", "markdown_inline", "printf", "python",
  "query", "regex", "rust", "sql", "toml", "tsx", "typescript", "vim",
  "vimdoc", "xml", "yaml",
}

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local installed = ts.get_installed()
    local missing = vim.tbl_filter(function(p)
      return not vim.tbl_contains(installed, p)
    end, desired_parsers)
    if #missing > 0 then
      ts.install(missing)
    end
  end,
})

-- Textobjects
require("nvim-treesitter-textobjects").setup()

local move = require("nvim-treesitter-textobjects.move")
local map = vim.keymap.set

map({ "n", "x", "o" }, "]f", function() move.goto_next_start("@function.outer") end, { desc = "Next Function Start" })
map({ "n", "x", "o" }, "]F", function() move.goto_next_end("@function.outer") end, { desc = "Next Function End" })
map({ "n", "x", "o" }, "]c", function() move.goto_next_start("@class.outer") end, { desc = "Next Class Start" })
map({ "n", "x", "o" }, "]C", function() move.goto_next_end("@class.outer") end, { desc = "Next Class End" })
map({ "n", "x", "o" }, "]a", function() move.goto_next_start("@parameter.inner") end, { desc = "Next Parameter" })
map({ "n", "x", "o" }, "[f", function() move.goto_previous_start("@function.outer") end, { desc = "Prev Function Start" })
map({ "n", "x", "o" }, "[F", function() move.goto_previous_end("@function.outer") end, { desc = "Prev Function End" })
map({ "n", "x", "o" }, "[c", function() move.goto_previous_start("@class.outer") end, { desc = "Prev Class Start" })
map({ "n", "x", "o" }, "[C", function() move.goto_previous_end("@class.outer") end, { desc = "Prev Class End" })
map({ "n", "x", "o" }, "[a", function() move.goto_previous_start("@parameter.inner") end, { desc = "Prev Parameter" })

local select = require("nvim-treesitter-textobjects.select")
map({ "x", "o" }, "af", function() select.select_textobject("@function.outer") end, { desc = "outer function" })
map({ "x", "o" }, "if", function() select.select_textobject("@function.inner") end, { desc = "inner function" })
map({ "x", "o" }, "ac", function() select.select_textobject("@class.outer") end, { desc = "outer class" })
map({ "x", "o" }, "ic", function() select.select_textobject("@class.inner") end, { desc = "inner class" })
map({ "x", "o" }, "aa", function() select.select_textobject("@parameter.outer") end, { desc = "outer parameter" })
map({ "x", "o" }, "ia", function() select.select_textobject("@parameter.inner") end, { desc = "inner parameter" })

-- Autotag and comments
require("nvim-ts-autotag").setup()
require("ts-comments").setup()
