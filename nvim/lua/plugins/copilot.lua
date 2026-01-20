return {
    "zbirenbaum/copilot.lua",
    opts = {
        suggestion = {
            auto_trigger = true,
            keymap = {
                accept = "<Tab>",
                accept_word = "<C-Right>",
                accept_line = "<C-l>",
                next = "<M-]>",
                prev = "<M-[>",
                dismiss = "<C-]>",
            },
        },
        filetypes = {
            markdown = true,
            yaml = true,
            gitcommit = true,
        },
    },
}
