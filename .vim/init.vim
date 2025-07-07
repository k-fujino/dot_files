" ------------------------------------------------------------
" 基本設定
" ------------------------------------------------------------
set nocompatible               " vi互換モードをオフ
syntax enable                  " シンタックスハイライト有効化
set number                     " 行番号表示
set hlsearch                   " 検索結果のハイライト
set ignorecase                 " 検索時に大文字小文字を区別しない
set smartcase                  " 検索パターンに大文字を含む場合は大文字小文字を区別
set showmatch                  " 対応する括弧をハイライト表示
set ambiwidth=double           " 全角文字の表示を適切に
set wildmode=longest,full      " コマンドライン補完の設定
set history=5000               " コマンド履歴の記録数
set hidden                     " バッファを閉じずに隠す
set t_Co=256                   " 256色対応
set laststatus=2               " ステータスラインを常に表示
set belloff=all                " ビープ音をオフ
set expandtab                  " タブをスペースに変換
set tabstop=2                  " タブの表示幅
set shiftwidth=2               " インデント幅
set softtabstop=2              " 連続した空白に対するタブ/バックスペースの動作幅
set nofixendofline             " ファイル末尾の改行を自動挿入しない

" カーソル形状の設定
if empty($TMUX)
  let &t_SI = "\<Esc>]50;CursorShape=1\x7"
  let &t_EI = "\<Esc>]50;CursorShape=0\x7"
else
  let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
  let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
endif


filetype plugin indent on
" ------------------------------------------------------------
" キーマッピング
" ------------------------------------------------------------
" Escをjjで
inoremap <silent> jj <ESC>

" バッファ切り替え
nnoremap <silent> <C-j> :bprev<CR>
nnoremap <silent> <C-k> :bnext<CR>

" VimShell
nnoremap <silent> ,s :VimShell<CR>



" ------------------------------------------------------------
" dein (プラグイン管理)
" ------------------------------------------------------------
" Required:
set runtimepath+=$HOME/.cache/dein/repos/github.com/Shougo/dein.vim

" Required:
if dein#load_state('$HOME/.cache/dein')
  call dein#begin('$HOME/.cache/dein')

  " Let dein manage dein
  call dein#add('$HOME/.cache/dein/repos/github.com/Shougo/dein.vim')

  " ------------------------------------------------------------
  " 補完関連プラグイン
  " ------------------------------------------------------------
  call dein#add('Shougo/deoplete.nvim')
  if !has('nvim')
    call dein#add('roxma/nvim-yarp')
    call dein#add('roxma/vim-hug-neovim-rpc')
  endif
  let g:deoplete#enable_at_startup = 1
  let g:deoplete#auto_complete_delay = 0
  let g:python3_host_prog = expand('~/.config/nvim/py_nvim_env/bin/python3')
  call dein#add('Shougo/denite.nvim')
  call dein#add('Shougo/deoplete-rct')  " Ruby補完用

  " ------------------------------------------------------------
  " 機能拡張プラグイン
  " ------------------------------------------------------------
  call dein#add('Shougo/vimproc.vim', {'build': 'make'})
  call dein#add('tpope/vim-fugitive')   " Git操作
  call dein#add('iberianpig/tig-explorer.vim')  " Tig連携
  call dein#add('rbgrouleff/bclose.vim')  " Tigの依存
  call dein#add('w0rp/ale')             " 構文チェック
  call dein#add('Shougo/vimshell', { 'rev': '3787e5' })

  " ------------------------------------------------------------
  " 言語別プラグイン
  " ------------------------------------------------------------
  call dein#add('jelera/vim-javascript-syntax')  " JavaScript
  call dein#add('fatih/vim-go')                  " Go言語

  " ------------------------------------------------------------
  " 移動・検索拡張プラグイン
  " ------------------------------------------------------------
  call dein#add('easymotion/vim-easymotion')
  call dein#add('lighttiger2505/gtags.vim')

  " ------------------------------------------------------------
  " ファイラープラグイン
  " ------------------------------------------------------------
  call dein#add('stevearc/oil.nvim')

  " tokyonight.nvimを追加
  call dein#add('folke/tokyonight.nvim')


  " Required:
  call dein#end()
  call dein#save_state()
endif

" If you want to install not installed plugins on startup.
if dein#check_install()
  call dein#install()
endif

" ------------------------------------------------------------
" プラグイン設定
" ------------------------------------------------------------
" EasyMotionの設定
let g:EasyMotion_do_mapping = 0  " デフォルトのマッピングを無効化
map <Leader> <Plug>(easymotion-prefix)
nmap s <Plug>(easymotion-overwin-f2)
let g:EasyMotion_smartcase = 1  " 大文字小文字を区別しない
map <Leader>j <Plug>(easymotion-j)
map <Leader>k <Plug>(easymotion-k)

" gtags設定
nnoremap <silent> <Space>f :Gtags -f %<CR>
nnoremap <silent> <Space>j :GtagsCursor<CR>
nnoremap <silent> <Space>d :<C-u>exe('Gtags '.expand('<cword>'))<CR>
nnoremap <silent> <Space>r :<C-u>exe('Gtags -r '.expand('<cword>'))<CR>

" Go言語設定
let g:go_bin_path = $GOPATH.'/bin'

" ファイラー設定
lua << EOF
require('oil').setup()
EOF

" 必要な設定
set termguicolors  " TrueColorサポートを有効化
colorscheme wombat256mod
"let g:tokyonight_style = 'night'

" '-'キーで親ディレクトリを開く設定
nnoremap - :Oil<CR>

" ------------------------------------------------------------
" ファイルタイプ設定
" ------------------------------------------------------------
" TypeScriptのシンタックスハイライト
autocmd BufRead,BufNewFile *.ts set filetype=javascript
autocmd BufRead,BufNewFile *.tsx set filetype=javascript

" ------------------------------------------------------------
" 表示関連
" ------------------------------------------------------------
" 全角スペースをハイライト表示
function! ZenkakuSpace()
    highlight ZenkakuSpace cterm=reverse ctermfg=DarkMagenta gui=reverse guifg=DarkMagenta
endfunction

if has('syntax')
    augroup ZenkakuSpace
        autocmd!
        autocmd ColorScheme * call ZenkakuSpace()
        autocmd VimEnter,WinEnter * match ZenkakuSpace /　/
    augroup END
    call ZenkakuSpace()
endif


" ------------------------------------------------------------
" oilで開いたfileにカラーが適用されないので
" ------------------------------------------------------------
augroup ForceRubySyntax
  autocmd!
  autocmd BufEnter,BufWinEnter *.rb syntax on | set filetype=ruby
augroup END

