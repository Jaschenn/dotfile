#!/usr/bin/env bash
# 用官方 Plum 安装/更新雾凇拼音，并用 stow 管理个人配置。
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RIME_DIR="$HOME/Library/Rime"
PLUM_DIR="${PLUM_DIR:-$HOME/.local/share/dotfile/plum}"
BACKUP_ROOT="${DOTFILE_BACKUP_DIR:-$HOME/dotfile_bak}"
CUSTOM_SOURCE="$ROOT/stow/rime/Library/Rime/squirrel.custom.yaml"
CUSTOM_TARGET="$RIME_DIR/squirrel.custom.yaml"
SQUIRREL_BIN="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"

# 迁移前本机已有的两行配置。它没有 patch:，实际未生效；字号真正改在
# squirrel.yaml 里。下面会把这项设置迁成正规的 custom patch。
LEGACY_CUSTOM_SHA256="1df2a530b3b3aedcfe159a2f9ce123473c4f4b535ece32bce7bbf7be6e2d33e0"

sha256_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

backup_file() {
    local source="$1" destination="$2"
    [ -e "$source" ] || [ -L "$source" ] || return 0
    mkdir -p "$(dirname "$destination")"
    rsync -a "$source" "$destination"
}

[ "$(uname -s)" = "Darwin" ] || die "Rime 模块目前只支持 macOS"
load_brew || die "Homebrew 还没装，先跑 'make brew'"
brew list --formula librime >/dev/null 2>&1 || die "librime 未安装，先跑 'make rime'"
brew list --cask squirrel-app >/dev/null 2>&1 || die "squirrel-app 未安装，先跑 'make rime'"
[ -x "$SQUIRREL_BIN" ] || die "找不到鼠须管：$SQUIRREL_BIN"
command -v stow >/dev/null 2>&1 || die "stow 未安装，先跑 'make core'"

use_proxy_if_available

# ── 安全接管唯一的个人配置 ───────────────────────────────────────
CUSTOM_ACTION="none"
if [ -L "$CUSTOM_TARGET" ] \
   && [ "$(readlink -f "$CUSTOM_TARGET" 2>/dev/null)" = "$(readlink -f "$CUSTOM_SOURCE" 2>/dev/null)" ]; then
    :
elif [ ! -e "$CUSTOM_TARGET" ] && [ ! -L "$CUSTOM_TARGET" ]; then
    CUSTOM_ACTION="link"
elif [ -f "$CUSTOM_TARGET" ] && { cmp -s "$CUSTOM_TARGET" "$CUSTOM_SOURCE" \
     || [ "$(sha256_file "$CUSTOM_TARGET")" = "$LEGACY_CUSTOM_SHA256" ]; }; then
    CUSTOM_ACTION="replace"
else
    die "$CUSTOM_TARGET 有未识别的修改；不会覆盖，请先人工合并"
fi

if [ "$CUSTOM_ACTION" = "replace" ]; then
    BACKUP_DIR="$BACKUP_ROOT/$(date '+%Y%m%d-%H%M%S')-$$"
    info "备份原有字号配置到 $BACKUP_DIR"
    backup_file "$RIME_DIR/squirrel.yaml" "$BACKUP_DIR/squirrel.yaml"
    backup_file "$CUSTOM_TARGET" "$BACKUP_DIR/squirrel.custom.yaml"
    rm -f "$CUSTOM_TARGET"
fi
if [ "$CUSTOM_ACTION" != "none" ]; then
    mkdir -p "$RIME_DIR"
    stow --no-folding --dir="$ROOT/stow" --target="$HOME" --restow rime
    ok "字号配置已链接到仓库"
fi

# ── 官方方式安装/更新雾凇拼音 ────────────────────────────────────
if [ -d "$PLUM_DIR/.git" ]; then
    info "更新 Plum"
    git -C "$PLUM_DIR" pull --ff-only
else
    info "安装 Plum"
    mkdir -p "$(dirname "$PLUM_DIR")"
    git clone --depth 1 "$(gh_url 'https://github.com/rime/plum.git')" "$PLUM_DIR"
fi

info "安装/更新雾凇拼音"
plum_dir="$PLUM_DIR" rime_dir="$RIME_DIR" \
    bash "$PLUM_DIR/rime-install" iDvel/rime-ice

if "$SQUIRREL_BIN" --reload >/dev/null 2>&1; then
    ok "鼠须管重新部署完成"
else
    warn "自动重新部署失败；请从鼠须管菜单手动选择「重新部署」"
fi

if defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null \
   | grep 'im.rime.inputmethod.Squirrel' >/dev/null; then
    ok "鼠须管已加入系统输入法"
else
    warn "还需手动操作：系统设置 → 键盘 → 输入法 → 添加鼠须管"
fi

ok "Rime 模块就绪"
