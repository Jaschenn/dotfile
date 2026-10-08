-- input_logger.lua
-- 把鼠须管（雾凇方案）上屏的文字按"句子"合并，按天写入文件。
-- 放置位置：~/Library/Rime/lua/input_logger.lua

---------------------------------------------------------------
-- 顶级配置（按需修改）
---------------------------------------------------------------
local CONFIG = {
  -- 日志目录，支持 ~ ；每天一个文件，如 2026-10-08.md
  -- 写进 iCloud 同步的 Obsidian 库，多台电脑共用同一份记录。
  log_dir = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/OS/(1)领域/(A)Life OS/RimeInputLog",

  -- 文件格式："md"（带日期标题的列表）或 "txt"（制表符分隔，最省空间）
  format = "md",

  -- 两次上屏间隔超过这么多秒，就认为是新的一句（秒）
  idle_gap = 5,

  -- 一句累积超过这么多字就强制写入（防止不打标点时无限累积）
  max_chars = 200,

  -- 遇到这些符号结尾时，认为一句话结束并立即写入
  end_marks = {
    ["。"] = true, ["！"] = true, ["？"] = true, ["；"] = true,
    ["…"] = true, ["!"] = true, ["?"] = true, [";"] = true,
  },

  -- 是否忽略纯英文/数字/ASCII 的上屏。
  -- 好处：过滤掉按回车上屏的拼音字母；坏处：英文单词也不会被记录。
  skip_pure_ascii = false,

  -- 是否记录 ASCII 模式（英文模式）下直接敲的字符。
  -- 通过监听按键实现：可打印字符、空格会被记录；带 Ctrl/Alt/Cmd 的快捷键不记录。
  -- 退格在中英文模式下都会同步删掉记录里的字（删过句末会撤回已写入的那句）；
  -- 回车、方向键、Tab、Esc、Ctrl/Cmd 组合键会结束当前句，之后的退格不再撤回。
  log_ascii = true,
}

---------------------------------------------------------------
-- 内部实现
---------------------------------------------------------------
local function expand(path)
  if path:sub(1, 1) == "~" then
    return (os.getenv("HOME") or "") .. path:sub(2)
  end
  return path
end

local LOG_DIR = expand(CONFIG.log_dir)
local IS_MD = (CONFIG.format == "md")
local EXT = IS_MD and ".md" or ".txt"

local dir_ready = false
local function ensure_dir()
  if dir_ready then return end
  os.execute('mkdir -p "' .. LOG_DIR .. '"')
  dir_ready = true
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

local function char_len(s)
  return (utf8 and utf8.len(s)) or #s
end

local function last_char(s)
  return s:match("[%z\1-\127\194-\244][\128-\191]*$")
end

-- 跨会话共享的句子缓冲
local buf = {}
local buf_chars = 0
local buf_start = nil   -- 这一句第一次上屏的时间
local buf_last = nil    -- 最近一次上屏的时间
local owner = nil       -- 当前句子属于哪个会话（每个应用/输入框一个 env）

-- 最近写入文件的一句。只要光标没动过（没按回车/方向键、没切走），
-- 退格删到它时就把它从文件里撤回，接着删。
local last = nil        -- { ts, text, path, line }

local function write_line(ts, text)
  ensure_dir()
  local day = os.date("%Y-%m-%d", ts)
  local path = LOG_DIR .. "/" .. day .. EXT
  local is_new = not file_exists(path)
  local f = io.open(path, "a")
  if not f then return end
  local hms = os.date("%H:%M:%S", ts)
  local line
  if IS_MD then
    if is_new then f:write("# ", day, "\n\n") end
    line = "- " .. hms .. " " .. text .. "\n"
  else
    line = hms .. "\t" .. text .. "\n"
  end
  f:write(line)
  f:close()
  last = { ts = ts, text = text, path = path, line = line }
end

-- 把 last 那一行从文件末尾删掉；文件末尾已不是它（被别处改过）就放弃
local function unwrite_last()
  local f = io.open(last.path, "r")
  if not f then return false end
  local s = f:read("*a")
  f:close()
  if s:sub(-#last.line) ~= last.line then return false end
  f = io.open(last.path, "w")
  if not f then return false end
  f:write(s:sub(1, #s - #last.line))
  f:close()
  return true
end

local function reset()
  buf, buf_chars, buf_start, buf_last = {}, 0, nil, nil
end

local function flush()
  if #buf == 0 then return end
  write_line(buf_start, table.concat(buf))
  reset()
end

-- 写入并断开：之后的退格不再撤回已写入的句子
local function seal()
  flush()
  last = nil
end

-- 按键/上屏来自另一个会话（切了应用或输入框）：上一处的句子到此为止
local function switch_owner(env)
  if owner ~= env then
    seal()
    owner = env
  end
end

local function add_text(text)
  local now = os.time()
  -- 停顿太久：先把上一句写掉
  if buf_last and (now - buf_last) > CONFIG.idle_gap then
    flush()
  end

  if not buf_start then buf_start = now end
  buf_last = now
  buf[#buf + 1] = text
  buf_chars = buf_chars + char_len(text)

  -- 句末标点或过长：立即写入
  if CONFIG.end_marks[last_char(text) or ""] or buf_chars >= CONFIG.max_chars then
    flush()
  end
end

-- 缓冲为空时，把刚写入文件的那句撤回到缓冲里继续编辑
local function reopen()
  if #buf > 0 then return true end
  if not last or not unwrite_last() then
    last = nil
    return false
  end
  buf, buf_chars = { last.text }, char_len(last.text)
  buf_start, buf_last = last.ts, os.time()
  last = nil
  return true
end

-- 退格：从缓冲末尾删一个字符
local function backspace()
  if not reopen() then return end
  local chunk = buf[#buf]
  local ch = last_char(chunk) or ""
  local rest = chunk:sub(1, #chunk - #ch)
  if rest == "" then
    buf[#buf] = nil
  else
    buf[#buf] = rest
  end
  buf_chars = math.max(0, buf_chars - 1)
  buf_last = os.time()
  if #buf == 0 then reset() end
end

-- Option+退格：删一个"词"。系统的分词规则拿不到，这里近似处理：
-- 先删末尾空白，末尾是英文/数字就删到词首，否则删掉最近一次上屏的内容。
local function delete_word()
  if not reopen() then return end
  local s = table.concat(buf)
  local trimmed = s:gsub("%s+$", "")
  local cut = trimmed:match("^(.-)[%w_]+$")
  if not cut then
    local chunk = buf[#buf]:gsub("%s+$", "")
    cut = trimmed:sub(1, #trimmed - #chunk)
  end
  if cut == "" then reset() return end
  buf, buf_chars, buf_last = { cut }, char_len(cut), os.time()
end

---------------------------------------------------------------
-- Rime processor 接口（只监听，不拦截按键）
---------------------------------------------------------------
local M = {}

function M.init(env)
  local ctx = env.engine.context
  -- 输入法上屏（中文模式的候选、标点，以及回车上屏的字母）
  env.commit_conn = ctx.commit_notifier:connect(function(c)
    local text = c:get_commit_text()
    if not text or text == "" then return end
    text = (text:gsub("[\r\n]+", " "))
    if CONFIG.skip_pure_ascii and not text:find("[\128-\255]") then
      return
    end
    switch_owner(env)
    add_text(text)
  end)
end

function M.fini(env)
  if env.commit_conn then env.commit_conn:disconnect() end
  if owner == env then
    seal()
    owner = nil
  end
end

local KEY_BACKSPACE = 0xff08

local function is_modifier(kc)
  return kc >= 0xffe1 and kc <= 0xffee
end

function M.func(key, env)
  -- 返回 2 (kNoop)：不拦截按键，只旁听
  if key:release() then return 2 end
  local ctx = env.engine.context
  -- 组字中的按键（包括删拼音的退格）由输入法自己处理，不影响已上屏文字
  if ctx:is_composing() then return 2 end

  local kc = key.keycode
  if is_modifier(kc) then return 2 end
  switch_owner(env)

  -- 退格：中英文模式都删缓冲，删空了会撤回上一句接着删
  if kc == KEY_BACKSPACE then
    if key:ctrl() or key:super() then
      seal()            -- 删到行首等，删多少无从知道
    elseif key:alt() then
      delete_word()
    else
      backspace()
    end
    return 2
  end

  -- Ctrl/Cmd 组合键（撤销、粘贴、全选……）之后文本状态不可信
  if key:ctrl() or key:super() then
    seal()
    return 2
  end

  -- 回车、方向键、Tab、Esc 等控制键：换行或光标移动，结束当前句
  if kc >= 0xff00 and not (kc >= 0xffb0 and kc <= 0xffb9) then
    seal()
    return 2
  end

  if key:alt() then return 2 end
  if not CONFIG.log_ascii then return 2 end
  if not ctx:get_option("ascii_mode") then return 2 end

  if kc >= 0x20 and kc <= 0x7e then
    add_text(string.char(kc))
  elseif kc >= 0xffb0 and kc <= 0xffb9 then      -- 小键盘数字
    add_text(string.char(kc - 0xffb0 + 0x30))
  end
  return 2
end

return M
