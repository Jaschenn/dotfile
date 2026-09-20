#!/usr/bin/env bash
# 把 Homebrew Fish 注册为合法 shell，并设为当前用户的默认登录 shell。
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

load_brew || die "Homebrew 还没装，先跑 'make brew'"
brew list --formula fish >/dev/null 2>&1 || die "Fish 未安装，先跑 'make shell'"

FISH_BIN="$(brew --prefix)/bin/fish"
[ -x "$FISH_BIN" ] || die "找不到 $FISH_BIN"

if grep -Fxq "$FISH_BIN" /etc/shells; then
    ok "$FISH_BIN 已登记在 /etc/shells"
else
    info "把 $FISH_BIN 加入 /etc/shells（需要管理员密码）"
    printf '%s\n' "$FISH_BIN" | sudo tee -a /etc/shells >/dev/null
    grep -Fxq "$FISH_BIN" /etc/shells || die "写入 /etc/shells 失败"
    ok "Fish 已登记为合法 shell"
fi

CURRENT_SHELL="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
if [ "$CURRENT_SHELL" = "$FISH_BIN" ]; then
    ok "Fish 已是默认登录 shell"
else
    info "把默认登录 shell 改为 ${FISH_BIN}（可能需要密码）"
    chsh -s "$FISH_BIN" || die "修改默认 shell 失败"
    ok "默认登录 shell 已改为 Fish；新终端窗口生效"
fi
