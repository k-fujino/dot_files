
"dein Scripts-----------------------------
if &compatible
  set nocompatible               " Be iMproved
endif

" Required:
set runtimepath+=$HOME/.cache/dein/repos/github.com/Shougo/dein.vim



" Required:
if dein#load_state('$HOME/.cache/dein')
  call dein#begin('$HOME/.cache/dein')

  " Let dein manage dein
  " Required:
  call dein#add('$HOME/.cache/dein/repos/github.com/Shougo/dein.vim')

  " Add or remove your plugins here:
  call dein#add('Shougo/neocomplete.vim')  "lua有効が必要
  call dein#add('Shougo/neocomplcache')
  call dein#add('Shougo/neosnippet-snippets')
  call dein#add('Shougo/neosnippet.vim')

  call dein#add('jelera/vim-javascript-syntax')
  call dein#add('tpope/vim-fugitive')

  call dein#add('easymotion/vim-easymotion')

  " 構文チェック
  call dein#add('w0rp/ale')


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

"printer settings-----------------------------
:set printoptions=duplex:long
:set printoptions+=paper:A4
:set printoptions+=wrap:y
:set printoptions+=number:y
:set printheader=%{strftime('%Y/%m/%d\ %H:%M')}
:set printfont=r:Myrica_M:h12
"End printer settings-------------------------

set number
set hlsearch
set ignorecase
set smartcase
set showmatch

set paste

set ambiwidth=double "japanese sikaku sankaku layout
set wildmode=list,full
set history=5000


"ctags-----------------------------
set fileformats=unix,dos,mac
set fileencodings=utf-8,sjis
set tags=./tags;$HOME
nnoremap <C-]> g<C-]>
inoremap <C-]> <ESC>g<C-]>


"cursol shape variable
if empty($TMUX)
  let &t_SI = "\<Esc>]50;CursorShape=1\x7"
  let &t_EI = "\<Esc>]50;CursorShape=0\x7"
"  let &t_SR = "\<Esc>]50;CursorShape=2\x7"
else
  let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
  let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
"  let &t_SR = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=2\x7\<Esc>\\"
endif

set t_Co=256

syntax on
"colorscheme desert
colorscheme wombat256mod

"easy motion用 --------------------
map <Leader> <Plug>(easymotion-prefix)
let g:EasyMotion_do_mapping = 0 " Disable default mappings

" Jump to anywhere you want with minimal keystrokes, with just one key binding.
" `s{char}{label}`
" nmap s <Plug>(easymotion-overwin-f)
" or
" `s{char}{char}{label}`
" Need one more keystroke, but on average, it may be more comfortable.
nmap s <Plug>(easymotion-overwin-f2)

" Turn on case insensitive feature
let g:EasyMotion_smartcase = 1

" JK motions: Line motions
map <Leader>j <Plug>(easymotion-j)
map <Leader>k <Plug>(easymotion-k)
"easy motion用 end--------------------

"typescriptのカラー表示
autocmd BufRead,BufNewFile *.ts set filetype=javascript
autocmd BufRead,BufNewFile *.tsx set filetype=javascript

"全角スペースをハイライト表示
function! ZenkakuSpace()
    highlight ZenkakuSpace cterm=reverse ctermfg=DarkMagenta gui=reverse guifg=DarkMagenta
endfunction
   
if has('syntax')
    augroup ZenkakuSpace
        autocmd!
        autocmd ColorScheme       * call ZenkakuSpace()
        autocmd VimEnter,WinEnter * match ZenkakuSpace /　/
    augroup END
    call ZenkakuSpace()
endif


set belloff=all
