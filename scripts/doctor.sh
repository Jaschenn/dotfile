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
if have op; then
    if op_ready; then
        ok "op 已登录"
        if op vault get "$OP_VAULT" >/dev/null 2>&1; then
            ok "vault「$OP_VAULT」可访问"
        else
            warn "vault「$OP_VAULT」不存在或没权限"
            FAIL=$((FAIL + 1))
        fi
    else
        warn "op 未登录 —— 打开 1Password app，设置 → 开发者 → 勾选「与 1Password CLI 集成」"
        WARN=$((WARN + 1))
    fi
fi

# ── 软链 ──────────────────────────────────────────────────────────
info "软链（stow）"
PKGS="$(ls -1 "$ROOT/stow" 2>/dev/null || true)"
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
            ok "$p（$n_ok 个文件）"
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
    if git ls-files -z | xargs -0 grep -lIE '(sk-[A-Za-z0-9_-]{16,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{20,})' 2>/dev/null | grep -q .; then
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
