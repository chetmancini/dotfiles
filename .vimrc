" BASICS
set nocompatible        " must be first line
filetype plugin indent on   " Automatically detect file types.
syntax on                   " syntax highlighting
set mouse=a                 " automatically enable mouse usage
set encoding=utf-8
"set shortmess+=filmnrxoOtT      " abbrev. of messages (avoids 'hit enter')
set viewoptions=folds,options,cursor,unix,slash " better unix / windows compatibility
set virtualedit=onemore         " allow for cursor beyond last character
set history=1000                " Store a ton of history (default is 20)
set fileformats+=mac

" VIM UI
colorscheme molokai
set background=dark     " Assume a dark background
let &t_Co=256
let g:molokai_original=1
set tabpagemax=15               " only show 15 tabs
set showmode                    " display the current mode
set cursorline                  " highlight current line
hi cursorline guibg=#333333     " highlight bg color of current line
hi CursorColumn guibg=#333333   " highlight cursor
set textwidth=79
set colorcolumn=85

" COMMAND LINE 
if has('cmdline_info')
    set ruler                   " show the ruler
    set rulerformat=%30(%=\:b%n%y%m%r%w\ %l,%c%V\ %P%) " a ruler on steroids
    set showcmd                 " show partial commands in status line and
                                " selected characters/lines in visual mode
endif
" STATUS LINE
if has('statusline')
    set laststatus=2
    set statusline=%<%f\   " Filename
    set statusline+=%w%h%m%r " Options
    set statusline+=\ [%{&ff}/%Y]            " filetype
    set statusline+=\ [%{getcwd()}]          " current dir
    set statusline+=\ [A=\%03.3b/H=\%02.2B] " ASCII / Hexadecimal value of char
    set statusline+=%=%-14.(%l,%c%V%)\ %p%%  " Right aligned file nav info
endif

" NUMBERING
set relativenumber
autocmd InsertEnter * :set number
autocmd InsertLeave * :set relativenumber

" MISC SETTINGS
"set undofile
set backspace=indent,eol,start  " backspace for dummys
set linespace=0                 " No extra spaces between rows
set showmatch                   " show matching brackets/parenthesis
set incsearch                   " find as you type search
set hlsearch                    " highlight search terms
set winminheight=0              " windows can be 0 line high 
set ignorecase                  " case insensitive search
set smartcase                   " case sensitive when uc present
set wildmenu                    " show list instead of just completing
set wildmode=list:longest,full  " command <Tab> completion, list matches, then longest common part, then all.
set whichwrap=b,s,h,l,<,>,[,]   " backspace and cursor keys wrap to
set scrolljump=5                " lines to scroll when cursor leaves screen
set scrolloff=3                 " minimum lines to keep above and below cursor
set foldenable                  " auto fold code
set gdefault                    " the /g flag on :s substitutions by default
set list
set listchars=tab:▸\ ,eol:¬
"set listchars=tab:>.,trail:.,extends:#,nbsp:. " Highlight problematic whitespace

" FORMATTING
set nowrap                      " wrap long lines
set autoindent                  " indent at the same level of the previous line
set shiftwidth=4                " use indents of 4 spaces
set tabstop=4                   " an indentation every four columns
set expandtab                   " tabs are spaces, not tabs
set softtabstop=4               " let backspace delete indent
set matchpairs+=<:>                " match, to be used with % 
set pastetoggle=<F12>           " pastetoggle (sane indentation on pastes)
set comments=sl:/*,mb:*,elx:*/  " auto format comment blocks
" Remove trailing whitespaces and ^M chars
"autocmd FileType c,cpp,java,php,js,python,twig,xml,yml autocmd BufWritePre <buffer> :call setline(1,map(getline(1,"$"),'substitute(v:val,"\\s\\+$","","")'))
autocmd FocusLost * :wa

" KEY MAPPINGS
    "The default leader is '\', but many people prefer ',' as it's in a standard location
let mapleader = ','
" Making it so ; works like : for commands. Saves typing and eliminates :W style typos due to lazy holding shift.
nnoremap ; :
" Easier moving in tabs and windows
map <C-J> <C-W>j<C-W>_
map <C-K> <C-W>k<C-W>_
map <C-L> <C-W>l<C-W>_
map <C-H> <C-W>h<C-W>_
map <C-K> <C-W>k<C-W>_
" Wrapped lines goes down/up to next row, rather than next line in file.
nnoremap j gj
nnoremap k gk
" Stupid shift key fixes
cmap WQ wq
cmap wQ wq
cmap Q q
cmap Tabe tabe

" Yank from the cursor to the end of the line, to be consistent with C and D.
nnoremap Y y$

""" Code folding options
nmap <leader>f0 :set foldlevel=0<CR>
nmap <leader>f1 :set foldlevel=1<CR>
nmap <leader>f2 :set foldlevel=2<CR>
nmap <leader>f3 :set foldlevel=3<CR>
nmap <leader>f4 :set foldlevel=4<CR>
nmap <leader>f5 :set foldlevel=5<CR>
nmap <leader>f6 :set foldlevel=6<CR>
nmap <leader>f7 :set foldlevel=7<CR>
nmap <leader>f8 :set foldlevel=8<CR>
nmap <leader>f9 :set foldlevel=9<CR>

"clearing highlighted search
"nmap <silent> <leader>/ :nohlsearch<CR>
" Shortcuts
" Change Working Directory to that of the current file
"cmap cwd lcd %:p:h
"cmap cd. lcd %:p:h
" visual shifting (does not exit Visual mode)
"vnoremap < <gv
"vnoremap > >gv 

    " Fix home and end keybindings for screen, particularly on mac
    " - for some reason this fixes the arrow keys too. huh.
" For when you forget to sudo.. Really Write the file.
cmap w!! w !sudo tee % >/dev/null

" PLUGINS
execute pathogen#infect()
set rtp+=/usr/local/opt/fzf

