
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
  " call dein#add('Shougo/neocomplete.vim')  "lua有効が必要
  " call dein#add('Shougo/neocomplcache')

" Ruby補完用
  call dein#add('Shougo/deoplete.nvim')
  if !has('nvim')
    call dein#add('roxma/nvim-yarp')
    call dein#add('roxma/vim-hug-neovim-rpc')
  endif
  let g:deoplete#enable_at_startup = 1
  let g:deoplete#auto_complete_delay = 0
  let g:python3_host_prog = expand('~/.pyenv/shims/python')
  call dein#add('Shougo/denite.nvim')

"  call dein#add('osyo-manga/vim-monster')
"  let g:monster#completion#backend = 'solargraph'
"  let g:neocomplete#sources#omni#input_patterns = {
"  \   "ruby" : '[^. *\t]\.\w*\|\h\w*::',
"  \}
"  let g:monster#completion#solargraph#backend = "async_solargraph_suggest"

  
  call dein#add('Shougo/deoplete-rct')

  call dein#add('Shougo/vimproc.vim', {'build': 'make'})

  " call dein#add('Shougo/neosnippet-snippets')
  " call dein#add('Shougo/neosnippet.vim')

  call dein#add('jelera/vim-javascript-syntax')
  call dein#add('tpope/vim-fugitive')

  call dein#add('easymotion/vim-easymotion')

  " 構文チェック
  call dein#add('w0rp/ale')

  " Go言語用
  call dein#add('fatih/vim-go')

  " gtag用
  call dein#add('lighttiger2505/gtags.vim')
  

  " You can specify revision/branch/tag.
  call dein#add('Shougo/vimshell', { 'rev': '3787e5' })

  " Required:
  call dein#end()
  call dein#save_state()
endif

" Required:
syntax enable

" If you want to install not installed plugins on startup.
if dein#check_install()
  call dein#install()
endif

"End dein Scripts-------------------------


set number
set hlsearch
set ignorecase
set smartcase
set showmatch

set ambiwidth=double "japanese sikaku sankaku layout
set wildmode=longest,full
set history=5000
set hidden


"ctags-----------------------------
"set fileformats=unix,dos,mac
"set fileencodings=utf-8,sjis
"set tags=./tags;$HOME
"nnoremap <C-]> g<C-]>
"inoremap <C-]> <ESC>g<C-]>

"gtags-----------------------------
nnoremap <silent> <Space>f :Gtags -f %<CR>
nnoremap <silent> <Space>j :GtagsCursor<CR>
nnoremap <silent> <Space>d :<C-u>exe('Gtags '.expand('<cword>'))<CR>
nnoremap <silent> <Space>r :<C-u>exe('Gtags -r '.expand('<cword>'))<CR>

" buffer 切り替え
nnoremap <silent> <C-j> :bprev<CR>
nnoremap <silent> <C-k> :bnext<CR>

"nnoremap <C-h> :Gtags -f %<CR>
"nnoremap <C-j> :GtagsCursor<CR>
"nnoremap <C-n> :cn<CR>
"nnoremap <C-p> :cp<CR>
"nnoremap <C-g> :Gtags
"
"nnoremap <C-o> :bp<CR>

" Go setting-----------------------
let g:go_bin_path = $GOPATH.'/bin'
" filetype plugin indent on



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

"file name 
set laststatus=2

"colorscheme desert
"colorscheme wombat256mod
colorscheme molokai

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

set expandtab "タブ入力を複数の空白入力に置き換える
set tabstop=2 "画面上でタブ文字が占める幅
set shiftwidth=2 "自動インデントでずれる幅
set softtabstop=2 "連続した空白に対してタブキーやバックスペースキーでカーソルが動く幅

"勝手にFile末尾に改行入れさせない
:set nofixendofline

" ------------------------------------------
nnoremap <silent> ,s :VimShell<CR>
" Escをjjで
inoremap <silent> jj <ESC>
" ------------------------------------------

