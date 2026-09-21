
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
"
" 原理：rime.vim 的引擎是全局的，且“进插入模式时若引擎已 started+ready
" 就自动启用”（im#on_insert_enter）。所以关键是——必须在你按 i 之前、
" 引擎就已经启动就绪。im#start() 是异步的（要连 rime daemon），如果拖到
" InsertEnter 那一刻才启动就来不及，当次插入不会启用（这是最初的坑）。
"
" 因此把启动时机提前到“进入写作类缓冲”时（FileType/BufEnter，普通模式）：
"   · 进写作类缓冲 → im#start()，异步就绪后按 i 由插件自动启用中文
"   · 进非写作类缓冲 → im#stop()，回到英文
" 任何时候仍可用 ;; 手动切换当前这次插入。
"
" 想加/减写作类文件，改这个列表即可。
let g:rime_auto_filetypes =
      \ get(g:, 'rime_auto_filetypes',
      \     ['markdown', 'text', 'gitcommit', 'gitrebase', 'mail',
      \      'pandoc', 'rst', 'asciidoc', 'org'])

function! s:RimeAutoSync() abort
  " 守卫用插件的加载标志，而不是 exists('*im#start')。
  " im#start 是 autoload 函数，其所在文件加载前 exists('*...') 恒为 0，
  " 会让本函数在插件已装的情况下也误判为“没装”而直接返回 —— 这正是
  " 最初“必须先手动 :IMStart 才生效”的原因。g:loaded_im_nvim 在插件
  " 加载时即置位，与 autoload 无关。
  if !get(g:, 'loaded_im_nvim', 0)
    return
  endif
  let l:started = im#state#get().started
  if index(g:rime_auto_filetypes, &filetype) >= 0
    if !l:started
      call im#start()
    endif
  elseif l:started
    call im#stop()
  endif
endfunction

augroup RimeAutoByFiletype
  autocmd!
  " FileType：文件加载/类型确定时（首次打开）
  " BufEnter：在已打开的缓冲间切换时（.md <-> .py）
  " 都在普通模式触发，给异步启动留出就绪时间；++nested 让插件自身的
  " autocmd（含 InsertEnter 启用逻辑）能正常连锁触发。
  autocmd FileType,BufEnter * ++nested call s:RimeAutoSync()
augroup END
