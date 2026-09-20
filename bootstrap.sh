#!/bin/sh
# 新机器上的第一条命令。只做三件事：装 CLT、克隆仓库、把活交给 make。
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/Jaschenn/dotfile/main/bootstrap.sh)"
#
# GitHub 完全访问不了的话，设个加速前缀：
#   GH_MIRROR=https://ghfast.top sh -c "$(curl ...)"
#
# 刻意用 POSIX sh 而不是 bash：这是唯一一个在仓库之外执行的脚本，
# 不能假设任何东西已经装好。真正的逻辑都在 Makefile 和 scripts/ 里。

set -eu

REPO_URL="https://github.com/Jaschenn/dotfile.git"
DOTFILE_DIR="${DOTFILE_DIR:-$HOME/dotfile}"

say()  { printf '\033[34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[31m  ✗\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "这套东西只针对 macOS"

# ── 1. Xcode Command Line Tools（git 的来源）──────────────────────
if ! xcode-select -p >/dev/null 2>&1; then
    say "安装 Xcode Command Line Tools（会弹系统对话框）"
    xcode-select --install 2>/dev/null || true
    printf '在弹出的对话框里点【安装】，装完后按回车继续... '
    read -r _ </dev/tty || true
    i=0
    while ! xcode-select -p >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -gt 120 ] && die "等待超时，装好后重新运行本脚本"
        sleep 10
    done
fi
say "Command Line Tools 就绪"

# ── 2. 克隆仓库 ───────────────────────────────────────────────────
if [ -d "$DOTFILE_DIR/.git" ]; then
    say "仓库已存在：$DOTFILE_DIR"
else
    URL="$REPO_URL"
    [ -n "${GH_MIRROR:-}" ] && URL="${GH_MIRROR%/}/$REPO_URL"
    say "克隆到 $DOTFILE_DIR"
    git clone --depth 1 "$URL" "$DOTFILE_DIR" || die \
        "克隆失败。GitHub 不通的话，先想办法弄个代理，或设 GH_MIRROR=https://ghfast.top 重试。"
fi

# ── 3. 交给 make ──────────────────────────────────────────────────
say "开始初始化"
cd "$DOTFILE_DIR"
exec make bootstrap
