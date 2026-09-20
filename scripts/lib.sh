#!/usr/bin/env bash
# 所有安装脚本共用的工具函数。用法： . "$(dirname "$0")/lib.sh"

set -euo pipefail

# ── 输出 ──────────────────────────────────────────────────────────

if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_DIM=$'\033[2m'
else
    C_RESET=''; C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_DIM=''
fi

info()  { printf '%s==>%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()    { printf '%s  ✓%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn()  { printf '%s  !%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()   { printf '%s  ✗%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }
skip()  { printf '%s  -%s %s\n' "$C_DIM"    "$C_RESET" "$*"; }

# 需要人工操作时用这个，把话说清楚再等回车
manual() {
    printf '\n%s┌─ 需要你手动操作 ─────────────────────────────%s\n' "$C_YELLOW" "$C_RESET"
    while [ $# -gt 0 ]; do printf '%s│%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; shift; done
    printf '%s└──────────────────────────────────────────────%s\n' "$C_YELLOW" "$C_RESET"
    if [ -t 0 ]; then
        printf '完成后按回车继续（Ctrl-C 中止）... '
        read -r _
    else
        warn '非交互环境，跳过等待。请确认上述操作已完成。'
    fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# ── 架构 ──────────────────────────────────────────────────────────

arch_name() {
    case "$(uname -m)" in
        arm64)  echo arm64 ;;
        x86_64) echo amd64 ;;
        *)      die "不支持的架构：$(uname -m)" ;;
    esac
}

brew_prefix() {
    case "$(uname -m)" in
        arm64) echo /opt/homebrew ;;
        *)     echo /usr/local ;;
    esac
}

# 让本进程能用上 brew（brew 刚装完时 PATH 里还没有）
load_brew() {
    if ! have brew; then
        local shellenv="$(brew_prefix)/bin/brew"
        [ -x "$shellenv" ] && eval "$("$shellenv" shellenv)"
    fi
    have brew
}

# ── 1Password ─────────────────────────────────────────────────────

# 所有密钥都放在这个 vault 里。条目清单见 README。
OP_VAULT="${OP_VAULT:-dotfile}"

op_ref() { echo "op://$OP_VAULT/$1"; }

op_ready() {
    # account list 只能说明配置过账户；whoami 才会验证当前会话确实已解锁。
    have op && op whoami >/dev/null 2>&1
}

# 读一个密钥；读不到返回非零，由调用方决定是致命还是降级
op_get() {
    local ref; ref="$(op_ref "$1")"
    op_ready || return 1
    op read "$ref" 2>/dev/null
}

# ── 代理 ──────────────────────────────────────────────────────────

# FlClash / mihomo 默认混合端口
PROXY_PORT="${PROXY_PORT:-7890}"
PROXY_URL="${PROXY_URL:-http://127.0.0.1:$PROXY_PORT}"

proxy_is_up() {
    # -G 只探测不发数据，-w 1 一秒超时
    nc -z -G 1 127.0.0.1 "$PROXY_PORT" >/dev/null 2>&1
}

# 本地代理在跑就用它，没跑就保持原样 —— 所以任何脚本都能无脑调用
use_proxy_if_available() {
    if [ -n "${NO_PROXY_AUTODETECT:-}" ]; then
        skip "已禁用代理自动探测（NO_PROXY_AUTODETECT）"
        return 0
    fi
    if proxy_is_up; then
        export http_proxy="$PROXY_URL"  https_proxy="$PROXY_URL"  all_proxy="socks5://127.0.0.1:$PROXY_PORT"
        export HTTP_PROXY="$PROXY_URL"  HTTPS_PROXY="$PROXY_URL"  ALL_PROXY="socks5://127.0.0.1:$PROXY_PORT"
        export no_proxy="localhost,127.0.0.1,::1"
        ok "已启用本地代理 $PROXY_URL"
    else
        warn "本地 $PROXY_PORT 端口没有代理在跑，后续下载可能会慢或失败"
        warn "先跑 'make proxy' 装好 FlClash 并开启系统代理"
    fi
}

# 走代理能不能真的出去
proxy_works() {
    curl -fsS --max-time 8 -o /dev/null https://github.com 2>/dev/null
}

# ── 下载 ──────────────────────────────────────────────────────────

# GitHub 直连不通时可以设 GH_MIRROR=https://ghfast.top 之类的前缀
gh_url() {
    local url="$1"
    if [ -n "${GH_MIRROR:-}" ]; then
        echo "${GH_MIRROR%/}/$url"
    else
        echo "$url"
    fi
}

# 让当前脚本及其所有子进程中的 git 都自动改写 GitHub URL。
# 这样不仅我们直接执行的 git clone/pull 会走镜像，Plum 等子脚本内部的
# GitHub clone 也会继承同一规则。使用进程级配置，不污染 ~/.gitconfig。
configure_github_git_mirror() {
    [ -n "${GH_MIRROR:-}" ] || return 0
    [ -z "${DOTFILE_GIT_MIRROR_CONFIGURED:-}" ] || return 0

    local index="${GIT_CONFIG_COUNT:-0}"
    local key="GIT_CONFIG_KEY_$index"
    local value="GIT_CONFIG_VALUE_$index"
    printf -v "$key" '%s' "url.${GH_MIRROR%/}/https://github.com/.insteadOf"
    printf -v "$value" '%s' "https://github.com/"
    export "$key" "$value"
    export GIT_CONFIG_COUNT=$((index + 1))
    export DOTFILE_GIT_MIRROR_CONFIGURED=1
}

configure_github_git_mirror

download() {
    local url="$1" out="$2"
    info "下载 $(basename "$out")"
    curl -fL --progress-bar --retry 3 --retry-delay 2 --connect-timeout 20 \
         -o "$out" "$url" || die "下载失败：$url"
}
