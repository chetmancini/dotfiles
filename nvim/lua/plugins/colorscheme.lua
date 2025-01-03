return {
    "catppuccin/nvim",
    -- "sainnhe/sonokai",
    -- "folke/tokyonight.nvim",
    -- "rose-pine/neovim",
    -- name = "sonokai",
    -- name = "rose-pine",
    -- name = "tokyonight",
    lazy = false,
    priority = 1000,
    config = function()
        --vim.cmd("colorscheme rose-pine"),
        -- vim.cmd.colorscheme("rose-pine")
        -- vim.cmd.colorscheme("tokyonight")
        vim.cmd.colorscheme("catppuccin")
        -- vim.cmd.colorscheme("sonokai")
    end,
    opts = function()
        return {
            transparent = true,
        }
    end,
}
