
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


" ── rime 按文件类型自动启停 ────────────────────────────────────────
"
" 只在“写作类”文件里自动开中文，代码文件默认英文。
" 原理：rime.vim 的引擎是全局的 —— 一旦 im#start()，之后每次进插入模式
" 都会自动开中文（im#on_insert_enter 里只要 started 就 enable）。所以要
" 做到“仅写作类自动开”，就得按 filetype 控制引擎的启停，而不是只 start。
"   · 进写作类文件的插入模式 → im#start()（进而自动 enable，中文就绪）
"   · 进非写作类文件的插入模式 → im#stop()（回到英文）
" 任何时候仍可用 ;; 手动切换当前这次插入。
"
" 想加/减写作类文件，改这个列表即可。
let g:rime_auto_filetypes =
      \ get(g:, 'rime_auto_filetypes',
      \     ['markdown', 'text', 'gitcommit', 'gitrebase', 'mail',
      \      'pandoc', 'rst', 'asciidoc', 'org'])

function! s:RimeAutoInsertEnter() abort
  " 插件没装（比如还没跑 make vim）就静默跳过，避免报错
  if !exists('*im#start') || !exists('*im#state#get')
    return
  endif
  let l:started = im#state#get().started
  if index(g:rime_auto_filetypes, &filetype) >= 0
    if !l:started
      call im#start()
    endif
  else
    if l:started
      call im#stop()
    endif
  endif
endfunction

augroup RimeAutoByFiletype
  autocmd!
  " 用 ++nested 让 im#start/stop 内部自身的 autocmd（InsertEnter 等）能正常触发
  autocmd InsertEnter * ++nested call s:RimeAutoInsertEnter()
augroup END
