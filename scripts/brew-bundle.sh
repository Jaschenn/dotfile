#!/usr/bin/env bash
# brew bundle 的薄封装：统一处理代理、找不到 Brewfile 的报错、以及 brew 未装的情况。
#   用法： brew-bundle.sh core        -> brew/Brewfile.core
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

MODULE="${1:?用法: brew-bundle.sh <模块名>}"
FILE="$(cd "$(dirname "$0")/.." && pwd)/brew/Brewfile.$MODULE"

[ -f "$FILE" ] || die "找不到 $FILE"
load_brew      || die "Homebrew 还没装，先跑 'make brew'"

use_proxy_if_available

# 每条 brew 命令前自动 update 会让整个流程慢到无法忍受
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

info "brew bundle：$MODULE"

# --no-upgrade：只装缺的，不顺手升级已有的。
# 升级应该是你主动做的事（brew upgrade），不该藏在初始化脚本里。
if brew bundle --file="$FILE" --no-upgrade; then
    ok "$MODULE 安装完成"
else
    die "brew bundle 失败。网络问题的话确认代理开着（make proxy-check）"
fi
