if g:dein#_cache_version != 100 | throw 'Cache loading error' | endif
let [plugins, ftplugin] = dein#load_cache_raw(['/Users/KoichiroFujino/.vimrc'])
if empty(plugins) | throw 'Cache loading error' | endif
let g:dein#_plugins = plugins
let g:dein#_ftplugin = ftplugin
let g:dein#_base_path = '/Users/KoichiroFujino/.cache/dein'
let g:dein#_runtime_path = '/Users/KoichiroFujino/.cache/dein/.cache/.vimrc/.dein'
let g:dein#_cache_path = '/Users/KoichiroFujino/.cache/dein/.cache/.vimrc'
let &runtimepath = '/Users/KoichiroFujino/.vim,/Users/KoichiroFujino/.cache/dein/repos/github.com/Shougo/dein.vim,/Users/KoichiroFujino/.cache/dein/.cache/.vimrc/.dein,/usr/local/vim80/share/vim/vimfiles,/usr/local/vim80/share/vim/vim80,/Users/KoichiroFujino/.cache/dein/.cache/.vimrc/.dein/after,/usr/local/vim80/share/vim/vimfiles/after,/Users/KoichiroFujino/.vim/after'
