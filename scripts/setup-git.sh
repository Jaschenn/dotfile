#!/usr/bin/env bash
# 用仓库管理通用 Git 配置，把身份和签名等机器私有设置迁到 config.local。
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GIT_DIR="$HOME/.config/git"
CONFIG_SOURCE="$ROOT/stow/git/.config/git/config"
IGNORE_SOURCE="$ROOT/stow/git/.config/git/ignore"
CONFIG_TARGET="$GIT_DIR/config"
IGNORE_TARGET="$GIT_DIR/ignore"
LOCAL_CONFIG="$GIT_DIR/config.local"
LEGACY_CONFIG="$HOME/.gitconfig"
BACKUP_ROOT="${DOTFILE_BACKUP_DIR:-$HOME/dotfile_bak}"
BACKUP_DIR=""

command -v git >/dev/null 2>&1 || die "Git 缺失；先跑 'make xcode'"
command -v stow >/dev/null 2>&1 || die "stow 缺失；先跑 'make core'"

ensure_backup_dir() {
    if [ -z "$BACKUP_DIR" ]; then
        BACKUP_DIR="$BACKUP_ROOT/$(date '+%Y-%m-%d_%H-%M-%S')-$$"
        mkdir -p "$BACKUP_DIR"
    fi
}

backup_item() {
    local source="$1" relative="$2" destination
    [ -e "$source" ] || [ -L "$source" ] || return 0
    ensure_backup_dir
    destination="$BACKUP_DIR/$relative"
    mkdir -p "$(dirname "$destination")"
    rsync -a "$source" "$destination"
}

same_link() {
    local source="$1" target="$2"
    [ -L "$target" ] \
        && [ "$(readlink -f "$target" 2>/dev/null)" = "$(readlink -f "$source" 2>/dev/null)" ]
}

migrate_identity_config() {
    local source="$1" relative="$2"
    [ -e "$source" ] || [ -L "$source" ] || return 0
    [ ! -e "$LOCAL_CONFIG" ] && [ ! -L "$LOCAL_CONFIG" ] \
        || die "$LOCAL_CONFIG 已存在；请先合并 $source，脚本不会覆盖"

    backup_item "$source" "$relative"
    mkdir -p "$GIT_DIR"
    if [ -L "$source" ]; then
        cp -L "$source" "$LOCAL_CONFIG"
        rm -f -- "$source"
    else
        mv "$source" "$LOCAL_CONFIG"
    fi
    chmod 600 "$LOCAL_CONFIG"
    info "$source 已迁到 $LOCAL_CONFIG"
}

mkdir -p "$GIT_DIR"

# Git 会同时读取 ~/.config/git/config 和 ~/.gitconfig。只允许其中一个旧配置
# 参与迁移，避免自动合并时改变设置优先级。
if ! same_link "$CONFIG_SOURCE" "$CONFIG_TARGET" \
   && { [ -e "$CONFIG_TARGET" ] || [ -L "$CONFIG_TARGET" ]; }; then
    if [ -e "$LEGACY_CONFIG" ] || [ -L "$LEGACY_CONFIG" ]; then
        die "$CONFIG_TARGET 与 $LEGACY_CONFIG 同时存在；请先人工合并"
    fi
    migrate_identity_config "$CONFIG_TARGET" ".config/git/config"
fi
if [ -e "$LEGACY_CONFIG" ] || [ -L "$LEGACY_CONFIG" ]; then
    migrate_identity_config "$LEGACY_CONFIG" ".gitconfig"
fi

if [ ! -e "$LOCAL_CONFIG" ] && [ ! -L "$LOCAL_CONFIG" ]; then
    printf '%s\n' '# 本机 Git 身份与签名配置；不进入 dotfile 仓库。' > "$LOCAL_CONFIG"
    chmod 600 "$LOCAL_CONFIG"
    warn "尚未配置 Git 身份；请设置 user.name 和 user.email"
fi

# 旧配置常把全局 ignore 指向 ~/.gitignore_global。现在由仓库统一管理，
# 删除这个旧键即可；旧文件本身保留，不做破坏性清理。
old_excludes="$(git config --file "$LOCAL_CONFIG" --get core.excludesfile 2>/dev/null || true)"
case "$old_excludes" in
    '~/.gitignore_global'|"$HOME/.gitignore_global")
        git config --file "$LOCAL_CONFIG" --unset-all core.excludesfile
        info "已移除旧的 core.excludesFile=$old_excludes"
        ;;
esac

# ignore 只包含可共享规则。已有文件无论是否相同都先备份，再交给 stow。
if ! same_link "$IGNORE_SOURCE" "$IGNORE_TARGET" \
   && { [ -e "$IGNORE_TARGET" ] || [ -L "$IGNORE_TARGET" ]; }; then
    if [ -d "$IGNORE_TARGET" ] && [ ! -L "$IGNORE_TARGET" ]; then
        die "$IGNORE_TARGET 是目录，无法安全接管"
    fi
    backup_item "$IGNORE_TARGET" ".config/git/ignore"
    rm -f -- "$IGNORE_TARGET"
fi

stow --no-folding --dir="$ROOT/stow" --target="$HOME" --restow git \
    || die "Git 配置建链失败"

name="$(git config --global --includes --get user.name 2>/dev/null || true)"
email="$(git config --global --includes --get user.email 2>/dev/null || true)"
if [ -n "$name" ] && [ -n "$email" ]; then
    ok "Git 身份：$name <$email>"
else
    warn "Git 通用配置已接管，但 user.name / user.email 尚未配置"
    warn "运行：git config --file ~/.config/git/config.local user.name '你的名字'"
    warn "运行：git config --file ~/.config/git/config.local user.email '你的邮箱'"
fi

if [ -n "$BACKUP_DIR" ]; then
    ok "旧 Git 配置已备份到 $BACKUP_DIR"
fi
ok "Git 配置完成"
