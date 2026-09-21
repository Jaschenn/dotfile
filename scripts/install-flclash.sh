#!/usr/bin/env bash
# FlClash —— 代理客户端。必须最先装好，否则后面装 brew / cask 全都要撞墙。
#
# FlClash 不在 homebrew-cask 里（只有名字相似的第三方 cask，不用）。
# 官方渠道只有 GitHub Release 的 dmg，所以这里自己下载 + 挂载 + 拷贝。
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

APP="/Applications/FlClash.app"
REPO="chen08209/FlClash"

# ── 代理模式 ──────────────────────────────────────────────────────
#
# 三选一，决定这一步做到哪：
#   none    不使用代理：跳过 FlClash 安装与代理配置，后续下载走直连
#   install 仅安装 FlClash：装好即返回，不等你导入订阅、不校验代理
#   full    安装 + 开代理：装好后等你导入订阅、开系统代理，并校验能出网（默认）
#
# 优先级：环境变量 PROXY_MODE > 交互式菜单（有终端时）> full（无终端时的默认）
resolve_proxy_mode() {
    case "${PROXY_MODE:-}" in
        none|install|full) echo "$PROXY_MODE"; return ;;
        '') ;;
        *)  die "PROXY_MODE 只能是 none / install / full，收到：$PROXY_MODE" ;;
    esac

    if [ ! -t 0 ]; then
        echo full   # 非交互（如 curl | sh 无 tty）：保持原行为
        return
    fi

    # 交互式菜单
    printf '\n%s请选择代理设置方式：%s\n' "$C_BLUE" "$C_RESET" >&2
    printf '  1) 不开代理       —— 跳过 FlClash，后续走直连（可配 GH_MIRROR/BREW_MIRROR）\n' >&2
    printf '  2) 仅安装 FlClash —— 装好就好，稍后自己导入订阅、开代理\n' >&2
    printf '  3) 安装 + 开代理  —— 装好并引导你导入订阅、校验出网（默认）\n' >&2
    printf '选择 [1/2/3，回车=3]：' >&2
    read -r choice
    case "$choice" in
        1) echo none ;;
        2) echo install ;;
        3|'') echo full ;;
        *) warn "无法识别「$choice」，按默认 3 处理" >&2; echo full ;;
    esac
}

MODE="$(resolve_proxy_mode)"

if [ "$MODE" = none ]; then
    info "已选择「不开代理」（PROXY_MODE=none），跳过 FlClash 安装与代理配置"
    if proxy_is_up; then
        ok "顺带一提：本地 $PROXY_PORT 已有代理在跑，后续步骤会自动用上"
    else
        warn "后续 brew / GitHub 下载将走直连。遇到网络问题可："
        warn "  · 重跑 'make proxy' 选择安装代理"
        warn "  · 或设 GH_MIRROR=https://ghfast.top、BREW_MIRROR=ustc 走国内镜像"
    fi
    exit 0
fi

if [ -d "$APP" ] && [ -z "${FORCE:-}" ]; then
    ok "FlClash 已安装（${APP}）"
else
    ARCH="$(arch_name)"

    # 版本号不写死：默认取 latest release。想钉版本就 FLCLASH_VERSION=0.8.98
    if [ -n "${FLCLASH_VERSION:-}" ]; then
        TAG="v${FLCLASH_VERSION#v}"
    else
        info "查询 FlClash 最新版本"
        TAG="$(curl -fsSL --max-time 20 "$(gh_url "https://api.github.com/repos/$REPO/releases/latest")" \
               | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)" \
            || die "拿不到版本号。可以指定 FLCLASH_VERSION=0.8.98 绕过，或设 GH_MIRROR。"
        [ -n "$TAG" ] || die "版本号解析为空，GitHub API 可能被墙。试试 FLCLASH_VERSION=0.8.98"
    fi
    VER="${TAG#v}"
    info "目标版本 ${TAG}（${ARCH}）"

    DMG_NAME="FlClash-$VER-macos-$ARCH.dmg"
    URL="$(gh_url "https://github.com/$REPO/releases/download/$TAG/$DMG_NAME")"

    TMP="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$TMP'" EXIT

    download "$URL" "$TMP/$DMG_NAME"

    info "挂载 dmg"
    MOUNT="$TMP/mnt"
    mkdir -p "$MOUNT"
    hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$TMP/$DMG_NAME" >/dev/null \
        || die "挂载失败，dmg 可能没下全"
    # shellcheck disable=SC2064
    trap "hdiutil detach '$MOUNT' >/dev/null 2>&1 || true; rm -rf '$TMP'" EXIT

    SRC="$(find "$MOUNT" -maxdepth 1 -name '*.app' -print -quit)"
    [ -n "$SRC" ] || die "dmg 里没找到 .app"

    info "拷贝到 /Applications"
    rm -rf "$APP"
    cp -R "$SRC" "$APP"

    # 从浏览器/curl 下来的 app 带 quarantine 属性，不清掉 Gatekeeper 会拦
    xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

    ok "FlClash $TAG 安装完成"
fi

# ── 订阅配置 ──────────────────────────────────────────────────────
#
# FlClash 是 Flutter GUI，没有 CLI，订阅链接没法脚本化导入。
# 能做的是：把链接从 1Password 取出来放进剪贴板，省掉你去翻的步骤。

if proxy_is_up; then
    ok "本地 $PROXY_PORT 端口已有代理在跑"
    if proxy_works; then
        ok "代理连通性正常"
        exit 0
    fi
    warn "端口在监听但访问 github.com 失败，检查 FlClash 的节点选择"
fi

SUB_ITEM="${FLCLASH_SUB_ITEM:-FlClash/subscription}"
COPIED=0
if op_ready; then
    if SUB="$(op_get "$SUB_ITEM")" && [ -n "$SUB" ]; then
        printf '%s' "$SUB" | pbcopy
        COPIED=1
        ok "订阅链接已从 1Password 复制到剪贴板（$(op_ref "$SUB_ITEM")）"
    else
        warn "1Password 里读不到 $(op_ref "$SUB_ITEM") —— 条目还没建，或字段名对不上"
    fi
else
    warn "op 还没装好或没登录，订阅链接得自己找"
    warn "（首次装机这是正常的：op 要等 make core 之后才有）"
fi

# ── 仅安装模式：装好就收工，不阻塞、不校验 ────────────────────────
if [ "$MODE" = install ]; then
    if [ "$COPIED" = 1 ]; then
        info "订阅链接已在剪贴板，随时可在 FlClash 里「配置 → 添加配置」粘贴导入"
    fi
    ok "FlClash 已就绪（仅安装模式）。需要开代理时，导入订阅并打开系统代理，或重跑 'make proxy' 选模式 3"
    exit 0
fi

# ── 完整模式：引导导入订阅、开代理，并校验出网 ────────────────────
open -a FlClash 2>/dev/null || warn "打不开 FlClash，手动从启动台打开"

if [ "$COPIED" = 1 ]; then
    manual "FlClash 已打开，订阅链接在剪贴板里。" \
           "1. 「配置」→「添加配置」→ 粘贴（⌘V）→ 提交" \
           "2. 回到「主页」，打开【系统代理】开关" \
           "3. 选一个能用的节点"
else
    manual "FlClash 已打开。" \
           "1. 「配置」→「添加配置」→ 粘贴你的订阅链接 → 提交" \
           "2. 回到「主页」，打开【系统代理】开关" \
           "3. 选一个能用的节点"
fi

info "验证代理"
proxy_is_up || die "127.0.0.1:$PROXY_PORT 仍然没在监听。确认 FlClash 的混合端口是 ${PROXY_PORT}（不是的话跑 make proxy PROXY_PORT=xxxx）。只想装不开代理可跑 'make proxy PROXY_MODE=install'"
use_proxy_if_available
proxy_works || die "代理端口通了但出不去，换个节点再跑 'make proxy'"
ok "代理就绪，可以继续 'make brew'"
