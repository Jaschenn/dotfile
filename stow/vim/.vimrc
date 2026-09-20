
syntax enable
filetype plugin indent on

" set termguicolors




set rtp+=/opt/homebrew/opt/fzf
" rime.vim
let g:im_rime_bin = expand('~/.vim/pack/plugins/start/rime.vim/cpp/build/rime-query')

let g:im_shared_data_dir = '/Library/Input Methods/Squirrel.app/Contents/SharedSupport'

" 雾凇拼音数据
let g:im_user_data_dir = expand('~/.local/share/rime-ice')



let g:im_log_file = expand('~/.local/state/log/vim/rime.log')
