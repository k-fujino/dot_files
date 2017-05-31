"dein Scripts-----------------------------
if &compatible
  set nocompatible               " Be iMproved
endif

" Required:
set runtimepath+=/Users/KoichiroFujino/.cache/dein/repos/github.com/Shougo/dein.vim

" Required:
if dein#load_state('/Users/KoichiroFujino/.cache/dein')
  call dein#begin('/Users/KoichiroFujino/.cache/dein')

  " Let dein manage dein
  " Required:
  call dein#add('/Users/KoichiroFujino/.cache/dein/repos/github.com/Shougo/dein.vim')

  " Add or remove your plugins here:
  call dein#add('Shougo/neosnippet.vim')
  call dein#add('Shougo/neosnippet-snippets')
  call dein#add('scrooloose/nerdtree')
  call dein#add('jelera/vim-javascript-syntax')

  " You can specify revision/branch/tag.
  call dein#add('Shougo/vimshell', { 'rev': '3787e5' })

  " Required:
  call dein#end()
  call dein#save_state()
endif

" Required:
filetype plugin indent on
syntax enable

" If you want to install not installed plugins on startup.
if dein#check_install()
  call dein#install()
endif

"End dein Scripts-------------------------

set number
set hlsearch
set showmatch

set paste

syntax on
colorscheme desert
"colorscheme wombat

"autocmd ColorScheme * highlight Comment ctermfg=22 guifg=#008800
"autocmd colorscheme molokai highlight Visual ctermbg=11
"colorscheme molokai
set t_Co=256
