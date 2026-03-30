require("gitsigns").setup({
  on_attach = function(buffer)
    local gs = require("gitsigns")
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buffer, desc = desc })
    end
    map("n", "]h", function() gs.nav_hunk("next") end, "Next Hunk")
    map("n", "[h", function() gs.nav_hunk("prev") end, "Prev Hunk")
    map("n", "<leader>ghs", gs.stage_hunk, "Stage Hunk")
    map("n", "<leader>ghr", gs.reset_hunk, "Reset Hunk")
    map("v", "<leader>ghs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage Hunk")
    map("v", "<leader>ghr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset Hunk")
    map("n", "<leader>ghS", gs.stage_buffer, "Stage Buffer")
    map("n", "<leader>ghR", gs.reset_buffer, "Reset Buffer")
    map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview Hunk")
    map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame Line")
    map("n", "<leader>ghd", gs.diffthis, "Diff This")
  end,
})
