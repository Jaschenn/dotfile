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
  -- 通过监听按键实现：可打印字符、空格、退格会被处理；
  -- 带 Ctrl/Alt/Cmd 的快捷键不记录；回车、方向键、Tab、Esc 会结束当前句。
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

local function write_line(ts, text)
  ensure_dir()
  local day = os.date("%Y-%m-%d", ts)
  local path = LOG_DIR .. "/" .. day .. EXT
  local is_new = not file_exists(path)
  local f = io.open(path, "a")
  if not f then return end
  local hms = os.date("%H:%M:%S", ts)
  if IS_MD then
    if is_new then f:write("# ", day, "\n\n") end
    f:write("- ", hms, " ", text, "\n")
  else
    f:write(hms, "\t", text, "\n")
  end
  f:close()
end

local function flush()
  if #buf == 0 then return end
  write_line(buf_start, table.concat(buf))
  buf, buf_chars, buf_start, buf_last = {}, 0, nil, nil
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

-- 中文模式：输入法上屏
local function on_commit(ctx)
  local text = ctx:get_commit_text()
  if not text or text == "" then return end
  text = (text:gsub("[\r\n]+", " "))

  if CONFIG.skip_pure_ascii and not text:find("[\128-\255]") then
    return
  end
  add_text(text)
end

-- ASCII 模式：退格时从缓冲末尾删一个字符
local function backspace()
  if #buf == 0 then return end
  local last = buf[#buf]
  local ch = last_char(last) or ""
  local rest = last:sub(1, #last - #ch)
  if rest == "" then
    buf[#buf] = nil
  else
    buf[#buf] = rest
  end
  buf_chars = math.max(0, buf_chars - 1)
  buf_last = os.time()
  if #buf == 0 then buf_start, buf_last, buf_chars = nil, nil, 0 end
end

---------------------------------------------------------------
-- Rime processor 接口（只监听，不拦截按键）
---------------------------------------------------------------
local M = {}

function M.init(env)
  local ctx = env.engine.context
  env.commit_conn = ctx.commit_notifier:connect(on_commit)
end

function M.fini(env)
  if env.commit_conn then env.commit_conn:disconnect() end
  flush()
end

function M.func(key, env)
  -- 返回 2 (kNoop)：不拦截按键，只旁听
  if key:release() then return 2 end
  local ctx = env.engine.context
  local kc = key.keycode

  -- 回车：没有在组字时，视为发送/换行，结束当前句（中英文模式都适用）
  if (kc == 0xff0d or kc == 0xff8d) and not ctx:is_composing() then
    flush()
    return 2
  end

  if not CONFIG.log_ascii then return 2 end
  if not ctx:get_option("ascii_mode") then return 2 end
  if ctx:is_composing() then return 2 end
  if key:ctrl() or key:alt() or key:super() then return 2 end

  if kc >= 0x20 and kc <= 0x7e then
    add_text(string.char(kc))
  elseif kc >= 0xffb0 and kc <= 0xffb9 then      -- 小键盘数字
    add_text(string.char(kc - 0xffb0 + 0x30))
  elseif kc == 0xff08 then                        -- BackSpace
    backspace()
  elseif kc < 0xffe1 or kc > 0xffee then          -- 非修饰键的其他控制键
    flush()                                       -- 方向键/Tab/Esc 等，光标位置不可信
  end
  return 2
end

return M
