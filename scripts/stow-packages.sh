#!/usr/bin/env bash
# 安全接管 stow 配置：比较现有目标，备份后再由仓库接管。
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STOW_DIR="$ROOT/stow"
TARGET="${TARGET:-$HOME}"
BACKUP_ROOT="${DOTFILE_BACKUP_DIR:-$HOME/dotfile_bak}"
MODE="${1:-}"
BACKUP_DIR=""
MIGRATED=0

usage() {
    die "用法：stow-packages.sh link|unlink|dry-run"
}

ensure_backup_dir() {
    if [ -z "$BACKUP_DIR" ]; then
        BACKUP_DIR="$BACKUP_ROOT/$(date '+%Y-%m-%d_%H-%M-%S')"
        if [ -e "$BACKUP_DIR" ] || [ -L "$BACKUP_DIR" ]; then
            BACKUP_DIR="$BACKUP_DIR-$$"
        fi
        mkdir -p "$BACKUP_DIR"
    fi
}

same_link() {
    local source="$1" target="$2"
    [ -L "$target" ] \
        && [ "$(readlink -f "$target" 2>/dev/null)" = "$(readlink -f "$source" 2>/dev/null)" ]
}

target_state() {
    local source="$1" target="$2"
    if same_link "$source" "$target"; then
        printf '%s\n' managed
    elif [ -d "$target" ] && [ ! -L "$target" ]; then
        printf '%s\n' directory
    elif [ -L "$target" ]; then
        printf '%s\n' symlink
    elif [ -f "$target" ]; then
        if cmp -s "$source" "$target"; then
            printf '%s\n' identical
        else
            printf '%s\n' different
        fi
    elif [ -e "$target" ]; then
        printf '%s\n' special
    else
        printf '%s\n' missing
    fi
}

for_each_source() {
    local callback="$1" package_dir package rel source
    for package_dir in "$STOW_DIR"/*/; do
        [ -d "$package_dir" ] || continue
        package="$(basename "$package_dir")"
        while IFS= read -r rel; do
            source="$package_dir$rel"
            "$callback" "$package" "$rel" "$source" "$TARGET/$rel"
        done < <(cd "$package_dir" && find . \( -type f -o -type l \) -not -name '.DS_Store' | sed 's|^\./||' | sort)
    done
}

preflight_target() {
    local package="$1" rel="$2" source="$3" target="$4" state
    state="$(target_state "$source" "$target")"
    case "$state" in
        directory|special)
            die "$target 是目录或特殊文件，无法安全接管（包：${package}）"
            ;;
    esac
}

show_target() {
    local package="$1" rel="$2" source="$3" target="$4" state
    state="$(target_state "$source" "$target")"
    case "$state" in
        managed)   skip "$rel 已由 $package 管理" ;;
        missing)   info "${rel}：将新建链接" ;;
        identical) info "${rel}：内容相同，将备份并接管" ;;
        different) warn "${rel}：内容不同，将备份并以仓库版本接管" ;;
        symlink)   warn "${rel}：当前指向其他位置，将备份链接并接管" ;;
        directory|special) warn "${rel}：无法安全接管（${state}）" ;;
    esac
}

migrate_target() {
    local package="$1" rel="$2" source="$3" target="$4" state destination
    state="$(target_state "$source" "$target")"
    case "$state" in
        managed|missing) return 0 ;;
        identical) info "${rel}：内容相同，备份后接管" ;;
        different) warn "${rel}：内容不同，备份后以仓库版本接管" ;;
        symlink) warn "${rel}：备份原链接后接管" ;;
        *) die "$target 无法安全接管（${state}）" ;;
    esac

    ensure_backup_dir
    destination="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$destination")"
    rsync -a "$target" "$destination"
    rm -f -- "$target"
    MIGRATED=$((MIGRATED + 1))
}

stow_all() {
    local action="$1" package_dir package
    for package_dir in "$STOW_DIR"/*/; do
        [ -d "$package_dir" ] || continue
        package="$(basename "$package_dir")"
        info "stow $package"
        stow --no-folding --dir="$STOW_DIR" --target="$TARGET" "$action" "$package"
    done
}

case "$MODE" in
    dry-run)
        info "预演配置接管（不会修改文件）"
        for_each_source show_target
        ;;
    link)
        command -v stow >/dev/null 2>&1 || die "stow 没装，先跑 'make core'"
        mkdir -p "$TARGET"
        # 先检查全部目标，避免迁移到一半才遇到不能安全处理的目录或特殊文件。
        for_each_source preflight_target
        for_each_source migrate_target
        stow_all --restow
        if [ "$MIGRATED" -gt 0 ]; then
            ok "已备份并接管 $MIGRATED 个现有文件：$BACKUP_DIR"
        else
            ok "所有配置均已由仓库管理"
        fi
        ;;
    unlink)
        command -v stow >/dev/null 2>&1 || die "stow 没装，先跑 'make core'"
        stow_all --delete
        ok "软链已拆除；备份和仓库文件均未改动"
        ;;
    *) usage ;;
esac
