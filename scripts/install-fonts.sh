#!/usr/bin/env bash
# 安装 Ghostty 所需字体。霞鹜字体从官方 release 下载并严格校验。
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_FILE="$ROOT/fonts/lxgw-wenkai-mono-screen.lock"
[ -f "$LOCK_FILE" ] || die "缺少 $LOCK_FILE"
# shellcheck disable=SC1090
. "$LOCK_FILE"

FONT_DIR="${FONT_DIR:-$HOME/Library/Fonts}"
TARGET="$FONT_DIR/$LXGW_FONT_FILE"
BACKUP_ROOT="${DOTFILE_BACKUP_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfile/backups}/fonts"

sha256_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

download_font() {
    local url="$1" out="$2" attempt=1
    info "下载 $(basename "$out")"
    while [ "$attempt" -le 5 ]; do
        if curl -fL --progress-bar --connect-timeout 20 -o "$out" "$url"; then
            return 0
        fi
        rm -f "$out"
        [ "$attempt" -lt 5 ] && warn "下载失败，第 $attempt 次重试" && sleep 2
        attempt=$((attempt + 1))
    done
    die "下载失败：$url"
}

[ "$(uname -s)" = "Darwin" ] || die "字体模块目前只支持 macOS"

if [ -f "$TARGET" ] && [ "$(sha256_file "$TARGET")" = "$LXGW_FONT_SHA256" ]; then
    ok "$LXGW_FONT_FAMILY v$LXGW_FONT_VERSION 已安装"
    exit 0
fi

use_proxy_if_available
TMP="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$TMP'" EXIT
DOWNLOADED="$TMP/$LXGW_FONT_FILE"
download_font "$(gh_url "$LXGW_FONT_URL")" "$DOWNLOADED"

actual="$(sha256_file "$DOWNLOADED")"
[ "$actual" = "$LXGW_FONT_SHA256" ] \
    || die "字体校验失败（期望 ${LXGW_FONT_SHA256}，实际 ${actual}）"

# fontconfig 并非 macOS 必备依赖；有 fc-scan 时再额外核对内嵌 family，
# 防止把普通版、非等宽版或 GB 版误当成目标字体。
if command -v fc-scan >/dev/null 2>&1; then
    families="$(fc-scan --format '%{family}' "$DOWNLOADED" 2>/dev/null || true)"
    case "$families" in
        *"$LXGW_FONT_FAMILY"*) ;;
        *) die "字体 family 不匹配：$families" ;;
    esac
fi

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    BACKUP_DIR="$BACKUP_ROOT/$(date '+%Y%m%d-%H%M%S')-$$"
    mkdir -p "$BACKUP_DIR"
    rsync -a "$TARGET" "$BACKUP_DIR/$LXGW_FONT_FILE"
    info "旧字体已备份到 $BACKUP_DIR"
fi

mkdir -p "$FONT_DIR"
install -m 0644 "$DOWNLOADED" "$TARGET"
[ "$(sha256_file "$TARGET")" = "$LXGW_FONT_SHA256" ] \
    || die "字体安装后校验失败：$TARGET"

ok "$LXGW_FONT_FAMILY v$LXGW_FONT_VERSION 安装完成"
info "已经打开的应用可能需要重启后才能看到新字体"
