#!/usr/bin/env bash
# 体检：逐项核对环境是否符合仓库的预期。
# 「一键安装」如果没有配套的体检，是不可信的 —— 很多失败是静默的。
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${TARGET:-$HOME}"
FAIL=0
WARN=0

check_cmd() {
    local cmd="$1" hint="${2:-}"
    if have "$cmd"; then
        ok "$cmd"
    else
        warn "$cmd 缺失 ${hint:+—— $hint}"
        FAIL=$((FAIL + 1))
    fi
}

check_app() {
    local app="$1" hint="${2:-}"
    if [ -d "/Applications/$app.app" ]; then
        ok "$app.app"
    else
        warn "$app.app 缺失 ${hint:+—— $hint}"
        FAIL=$((FAIL + 1))
    fi
}

# ── 基础 ──────────────────────────────────────────────────────────
info "基础工具"
if xcode-select -p >/dev/null 2>&1; then ok "Command Line Tools"; else warn "Command Line Tools 缺失 —— make xcode"; FAIL=$((FAIL+1)); fi
load_brew >/dev/null 2>&1 || true
check_cmd git
check_cmd brew "make brew"
check_cmd stow "make core"
check_cmd op   "make core"
check_cmd mas  "make core"

# ── Git ───────────────────────────────────────────────────────────
info "Git"
GIT_NAME="$(git config --global --includes --get user.name 2>/dev/null || true)"
GIT_EMAIL="$(git config --global --includes --get user.email 2>/dev/null || true)"
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
    ok "身份：$GIT_NAME <$GIT_EMAIL>"
else
    warn "user.name / user.email 未配置 —— make git"
    FAIL=$((FAIL + 1))
fi
GIT_EXCLUDES="$(git config --global --includes --path --get core.excludesfile 2>/dev/null || true)"
if [ "$GIT_EXCLUDES" = "$HOME/.config/git/ignore" ]; then
    ok "全局 ignore：$GIT_EXCLUDES"
else
    warn "core.excludesFile 未指向仓库配置 —— make git"
    FAIL=$((FAIL + 1))
fi

# ── 网络 ──────────────────────────────────────────────────────────
info "网络"
check_app FlClash "make proxy"
if proxy_is_up; then
    ok "代理端口 $PROXY_PORT 在监听"
    use_proxy_if_available >/dev/null
    if proxy_works; then ok "代理出网正常"; else warn "端口通但出不去，换节点"; FAIL=$((FAIL+1)); fi
else
    warn "代理端口 $PROXY_PORT 没在监听 —— FlClash 没开或没启用系统代理"
    WARN=$((WARN + 1))
fi

# ── 1Password ─────────────────────────────────────────────────────
info "1Password"
check_app "1Password" "先完成 README 的阶段 0"
if have op; then
    if op_ready; then
        ok "op CLI 可访问 1Password"
        if op vault get "$OP_VAULT" >/dev/null 2>&1; then
            ok "vault「${OP_VAULT}」可访问"
        else
            warn "vault「${OP_VAULT}」不存在或没权限"
            FAIL=$((FAIL + 1))
        fi
    else
        warn "op 未登录 —— 打开 1Password app，设置 → 开发者 → 勾选「与 1Password CLI 集成」"
        WARN=$((WARN + 1))
    fi
fi

OP_AGENT="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [ -S "$OP_AGENT" ]; then
    ok "1Password SSH Agent socket"
    AGENT_STATUS=0
    AGENT_OUTPUT="$(SSH_AUTH_SOCK="$OP_AGENT" ssh-add -l 2>&1)" || AGENT_STATUS=$?
    if [ "$AGENT_STATUS" -eq 0 ]; then
        ok "SSH Agent 有可用密钥"
    elif [ "$AGENT_OUTPUT" = "The agent has no identities." ]; then
        warn "SSH Agent 已开启，但没有可用 SSH Key"
        WARN=$((WARN + 1))
    else
        warn "SSH Agent 查询失败：${AGENT_OUTPUT:-未知错误}"
        WARN=$((WARN + 1))
    fi
else
    warn "1Password SSH Agent 未开启 —— make onepassword"
    FAIL=$((FAIL + 1))
fi

# ── 字体 ──────────────────────────────────────────────────────────
info "字体"
if have brew && brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
    ok "JetBrains Mono Nerd Font"
else
    warn "JetBrains Mono Nerd Font 缺失 —— make fonts"
    FAIL=$((FAIL + 1))
fi

FONT_LOCK="$ROOT/fonts/lxgw-wenkai-mono-screen.lock"
if [ -f "$FONT_LOCK" ]; then
    # shellcheck disable=SC1090
    . "$FONT_LOCK"
    FONT_TARGET_DIR="${FONT_DIR:-$TARGET/Library/Fonts}"
    FONT_FILE="$FONT_TARGET_DIR/$LXGW_FONT_FILE"
    if [ -f "$FONT_FILE" ] \
       && [ "$(shasum -a 256 "$FONT_FILE" | awk '{print $1}')" = "$LXGW_FONT_SHA256" ]; then
        ok "$LXGW_FONT_FAMILY v$LXGW_FONT_VERSION"
    else
        warn "$LXGW_FONT_FAMILY 缺失或版本不符 —— make fonts"
        FAIL=$((FAIL + 1))
    fi

    if have fc-list && fc-list : family 2>/dev/null | grep -F "$LXGW_FONT_FAMILY" >/dev/null; then
        ok "字体 family：$LXGW_FONT_FAMILY"
    elif have fc-list; then
        warn "字体文件存在但 family 未被识别：$LXGW_FONT_FAMILY"
        FAIL=$((FAIL + 1))
    fi
fi

# ── Shell / 终端 ──────────────────────────────────────────────────
info "Shell / 终端"
check_cmd fish "make shell"
check_cmd fzf "make shell"
check_cmd starship "make shell"
check_cmd tldr "make shell"
check_cmd yazi "make shell"
check_cmd zellij "make shell"
check_cmd zoxide "make shell"
check_app Ghostty "make shell"

FISH_BIN="$(command -v fish 2>/dev/null || true)"
if [ -n "$FISH_BIN" ] && grep -Fxq "$FISH_BIN" /etc/shells 2>/dev/null; then
    ok "Fish 已登记在 /etc/shells"
else
    warn "Fish 未登记为合法 shell —— make shell"
    FAIL=$((FAIL + 1))
fi
ACCOUNT_SHELL="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
if [ -n "$FISH_BIN" ] && [ "$ACCOUNT_SHELL" = "$FISH_BIN" ]; then
    ok "Fish 是默认登录 shell"
else
    warn "默认登录 shell 不是 Fish —— make shell"
    FAIL=$((FAIL + 1))
fi

# ── 开发工具 ──────────────────────────────────────────────────────
info "开发工具"
check_cmd gh "make dev"
check_cmd htop "make dev"
check_cmd lazygit "make dev"
check_cmd node "make dev"
check_cmd pnpm "make dev"
check_cmd rustc "make dev"
check_cmd uv "make dev"
check_cmd watchman "make dev"

# ── 桌面应用 ──────────────────────────────────────────────────────
info "桌面应用"
check_app "Alfred 5" "make apps"
check_app "Google Chrome" "make apps"
check_app Obsidian "make apps"
check_app OmniFocus "make apps"
check_app Zotero "make apps"

# ── Rime / 鼠须管 ────────────────────────────────────────────────
info "Rime / 鼠须管"
check_cmd rime_deployer "make rime"
if [ -d "/Library/Input Methods/Squirrel.app" ]; then
    ok "Squirrel.app"
else
    warn "Squirrel.app 缺失 —— make rime"
    FAIL=$((FAIL + 1))
fi

RIME_TARGET="$TARGET/Library/Rime"
if [ -f "$RIME_TARGET/rime_ice.schema.yaml" ]; then
    ok "雾凇拼音方案"
else
    warn "雾凇拼音方案缺失 —— make rime"
    FAIL=$((FAIL + 1))
fi

if [ -f "$RIME_TARGET/build/rime_ice.schema.yaml" ]; then
    ok "雾凇拼音已部署"
else
    warn "雾凇拼音尚未生成 build —— 从鼠须管菜单重新部署"
    WARN=$((WARN + 1))
fi

if macos_input_source_enabled 'im.rime.inputmethod.Squirrel'; then
    ok "鼠须管已加入系统输入法"
else
    warn "鼠须管尚未加入系统输入法"
    WARN=$((WARN + 1))
fi

# ── Vim / rime.vim ────────────────────────────────────────────────
info "Vim / rime.vim"
VIM_RIME_PLUGIN="${VIM_RIME_PLUGIN_DIR:-$HOME/.vim/pack/plugins/start/rime.vim}"
VIM_RIME_DATA="${VIM_RIME_DATA_DIR:-$HOME/.local/share/rime-ice}"
if [ -d "$VIM_RIME_PLUGIN/.git" ]; then
    ok "rime.vim"
else
    warn "rime.vim 缺失 —— make vim"
    FAIL=$((FAIL + 1))
fi
if [ -x "$VIM_RIME_PLUGIN/cpp/build/rime-query" ]; then
    ok "rime-query"
else
    warn "rime-query 缺失 —— make vim"
    FAIL=$((FAIL + 1))
fi
if [ -d "$VIM_RIME_DATA/.git" ]; then
    ok "Vim 专用 rime-ice"
else
    warn "Vim 专用 rime-ice 缺失 —— make vim"
    FAIL=$((FAIL + 1))
fi

# ── 软链 ──────────────────────────────────────────────────────────
info "软链（stow）"
PKGS="$(cd "$ROOT/stow" 2>/dev/null && find . -maxdepth 1 -mindepth 1 -type d | sed 's|^\./||' | sort || true)"
if [ -z "$PKGS" ]; then
    skip "stow/ 下还没有包"
else
    for p in $PKGS; do
        # 逐个核对包内每个文件，在 $HOME 下是不是指向仓库的软链
        n_ok=0; n_bad=0
        while IFS= read -r rel; do
            tgt="$TARGET/$rel"
            src="$ROOT/stow/$p/$rel"
            if [ -L "$tgt" ] && [ "$(readlink -f "$tgt" 2>/dev/null)" = "$(readlink -f "$src" 2>/dev/null)" ]; then
                n_ok=$((n_ok + 1))
            else
                n_bad=$((n_bad + 1))
                warn "  $rel 未正确链接"
            fi
        done < <(cd "$ROOT/stow/$p" && find . -type f -not -name '.DS_Store' | sed 's|^\./||')
        if [ "$n_bad" = 0 ]; then
            ok "${p}（$n_ok 个文件）"
        else
            FAIL=$((FAIL + 1))
        fi
    done
fi

# ── 仓库卫生 ──────────────────────────────────────────────────────
info "仓库卫生"
cd "$ROOT"
if git rev-parse --git-dir >/dev/null 2>&1; then
    # 被 git 跟踪的文件里有没有疑似密钥
    if git ls-files -z | xargs -0 grep -lIE '(sk-[A-Za-z0-9_-]{16,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{20,})' 2>/dev/null | grep . >/dev/null; then
        warn "被跟踪的文件里发现疑似密钥："
        git ls-files -z | xargs -0 grep -lIE '(sk-[A-Za-z0-9_-]{16,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{20,})' 2>/dev/null | sed 's/^/      /'
        FAIL=$((FAIL + 1))
    else
        ok "被跟踪的文件里没有明文密钥"
    fi

    # 大文件不该进仓库
    big="$(git ls-files -z | xargs -0 -I{} find {} -size +5M 2>/dev/null || true)"
    if [ -n "$big" ]; then
        warn "被跟踪的大文件（>5M）："; echo "$big" | sed 's/^/      /'
        WARN=$((WARN + 1))
    else
        ok "没有被跟踪的大文件"
    fi
fi

# ── 汇总 ──────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -gt 0 ]; then
    die "$FAIL 项失败，$WARN 项警告"
elif [ "$WARN" -gt 0 ]; then
    warn "全部通过，但有 $WARN 项警告"
else
    ok "全部通过"
fi
