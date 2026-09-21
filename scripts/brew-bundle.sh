#!/usr/bin/env bash
# brew bundle 的封装：处理代理、Brewfile 缺失、brew 未装，并对两类最常见的
# bundle 失败做自愈或清晰报告，而不是一失败就整体中止。
#
#   A. 链接冲突（"Target ... already exists" / "Could not symlink"）
#      —— formula 已经装好（pour 进 Cellar），只是有个非 brew 的文件占了
#      /opt/homebrew/bin 里的位置（常见：pnpm/corepack、独立脚本装的 CLI）。
#      安全时自动 `brew link --overwrite` 修复。
#   B. formula 互斥（"conflicting formulae are installed"）
#      —— 两个 formula 抢同一个命令（如 tldr vs tlrc）。这需要卸载另一个，
#      有破坏性，不自动做，只清楚报告该跑什么。
#
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

PREFIX="$(brew --prefix)"
CELLAR="$(brew --cellar 2>/dev/null || echo "$PREFIX/Cellar")"

# brew bundle 跑一遍，输出同时打到屏幕和一个文件供解析。返回 bundle 的退出码。
run_bundle() {
    local out="$1"
    # --no-upgrade：只装缺的，不顺手升级已有的。升级该是主动行为，不藏在初始化里。
    brew bundle --file="$FILE" --no-upgrade 2>&1 | tee "$out"
    return "${PIPESTATUS[0]}"
}

# 某个 formula 若 link 会覆盖的文件里，有没有属于「另一个 keg」的？
# 有 -> 是真实的 formula 冲突，不能随便覆盖；无 -> 只是占位的杂散文件，可安全覆盖。
#
# dry-run 的行有两种形态：
#   /opt/homebrew/bin/pnpm -> /opt/homebrew/lib/node_modules/pnpm/bin/pnpm.cjs   （占位是符号链接）
#   /opt/homebrew/bin/foo                                                        （占位是实体文件）
# 取路径本身，再看它当前指向哪；指向 Cellar 才算真实冲突。
overwrite_is_safe() {
    local f="$1" line path target
    while IFS= read -r line; do
        path="${line%% -> *}"           # 去掉 " -> 目标" 后缀，得到占位路径
        case "$path" in
            "$PREFIX"/*) ;;             # 只关心落在 brew 前缀里的
            *) continue ;;              # 跳过 "Would remove:" 等表头
        esac
        [ -e "$path" ] || [ -L "$path" ] || continue
        if [ -L "$path" ]; then
            target="$(readlink "$path" 2>/dev/null || true)"
            case "$target" in
                "$CELLAR"/*|*/Cellar/*|../Cellar/*|../../Cellar/*)
                    return 1 ;;         # 指向其它 keg = 真实冲突，不能覆盖
            esac
        fi
    done < <(brew link --overwrite --dry-run "$f" 2>/dev/null)
    return 0
}

# 从 bundle 输出里解析 brew 自己建议的 "brew link --overwrite NAME"
parse_overwrite_candidates() {
    sed -n 's/.*brew link --overwrite \([A-Za-z0-9._+-]*\).*/\1/p' "$1" | sort -u
}

# 解析 B 类互斥：brew 会提示 "Please `brew unlink NAME`"
parse_conflicts() {
    sed -n 's/.*brew unlink \([A-Za-z0-9._+-]*\).*/\1/p' "$1" | sort -u
}

info "brew bundle：$MODULE"

OUT="$(mktemp -t brewbundle.XXXXXX)"
trap 'rm -f "$OUT"' EXIT

if run_bundle "$OUT"; then
    ok "$MODULE 安装完成"
    exit 0
fi

warn "brew bundle 有条目失败，尝试自愈链接冲突……"

HEALED=0
BLOCKED=""
for f in $(parse_overwrite_candidates "$OUT"); do
    brew list --formula --versions "$f" >/dev/null 2>&1 || continue   # 没装就不是链接问题
    if overwrite_is_safe "$f"; then
        info "重新链接（覆盖占位文件）：brew link --overwrite $f"
        if brew link --overwrite "$f" >/dev/null 2>&1; then
            ok "$f 已链接"
            HEALED=$((HEALED + 1))
        else
            warn "$f 链接失败"
            BLOCKED="$BLOCKED $f"
        fi
    else
        warn "$f 的链接与另一个 formula 冲突，跳过（需人工确认）"
        BLOCKED="$BLOCKED $f"
    fi
done

# B 类：formula 互斥，不自动卸载，只报告
CONFLICTS="$(parse_conflicts "$OUT")"

if [ "$HEALED" -gt 0 ]; then
    info "重跑 brew bundle 确认"
    if run_bundle "$OUT"; then
        ok "$MODULE 安装完成（自愈 $HEALED 个链接冲突）"
        exit 0
    fi
fi

# 到这里说明还有没解决的问题，给出可执行的下一步而不是笼统报错
echo ""
warn "brew bundle 仍未全部成功，需要人工处理："
if [ -n "$CONFLICTS" ]; then
    for c in $CONFLICTS; do
        warn "  · 命令冲突：有 formula 与已安装的「$c」抢同一个命令。"
        warn "    确认要用 Brewfile 里的版本，就先卸掉旧的： brew uninstall $c"
    done
fi
if [ -n "$BLOCKED" ]; then
    for b in $BLOCKED; do
        warn "  · $b 链接未成功，手动查看： brew link --overwrite --dry-run $b"
    done
fi
if [ -z "$CONFLICTS" ] && [ -z "$BLOCKED" ]; then
    warn "  · 可能是网络问题，确认代理开着（make proxy-check），或看上面的具体报错"
fi
die "处理完上面的问题后，重跑 'make $MODULE'"
