call plug#begin('~/.vim/plugged')

" 在这里写插件，格式 Plug '用户名/仓库名'
Plug 'preservim/nerdtree'   " 文件树
Plug 'vim-airline/vim-airline' " 状态栏
Plug 'TSalmon3/rime.vim' "中文输入法"
call plug#end()


set rtp+=/opt/homebrew/opt/fzf
