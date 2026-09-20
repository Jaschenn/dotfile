#!/usr/bin/env bash
# 安装/更新 rime.vim、独立的 rime-ice 数据，并编译 rime-query。
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

PLUGIN_DIR="${VIM_RIME_PLUGIN_DIR:-$HOME/.vim/pack/plugins/start/rime.vim}"
DATA_DIR="${VIM_RIME_DATA_DIR:-$HOME/.local/share/rime-ice}"
PLUGIN_REPO="https://github.com/TSalmon3/rime.vim.git"
DATA_REPO="https://github.com/iDvel/rime-ice.git"

clone_or_update() {
    local url="$1" destination="$2" label="$3"
    if [ -d "$destination/.git" ]; then
        info "更新 $label"
        git -C "$destination" pull --ff-only
    elif [ -e "$destination" ]; then
        die "$destination 已存在但不是 Git checkout；不会覆盖"
    else
        info "安装 $label"
        mkdir -p "$(dirname "$destination")"
        git clone --depth 1 "$(gh_url "$url")" "$destination"
    fi
}

load_brew || die "Homebrew 还没装，先跑 'make brew'"
brew list --formula librime >/dev/null 2>&1 || die "librime 未安装，先跑 'make rime'"
command -v clang++ >/dev/null 2>&1 || die "clang++ 缺失，先安装 Xcode Command Line Tools"

use_proxy_if_available
clone_or_update "$PLUGIN_REPO" "$PLUGIN_DIR" "rime.vim"
clone_or_update "$DATA_REPO" "$DATA_DIR" "Vim 专用 rime-ice"

BREW_PREFIX="$(brew --prefix)"
BUILD_DIR="$PLUGIN_DIR/cpp/build"
TMP="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$TMP'" EXIT

info "编译 rime-query"
clang++ -std=c++17 -O2 -Wall \
    -I"$PLUGIN_DIR/cpp/3rd" \
    -I"$BREW_PREFIX/include" \
    -L"$BREW_PREFIX/lib" \
    "$PLUGIN_DIR/cpp/rime-query.cc" \
    -lrime \
    -o "$TMP/rime-query"

mkdir -p "$BUILD_DIR"
install -m 0755 "$TMP/rime-query" "$BUILD_DIR/rime-query"
[ -x "$BUILD_DIR/rime-query" ] || die "rime-query 安装失败"
ok "rime.vim 与 rime-query 就绪"
