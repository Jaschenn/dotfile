#!/usr/bin/env bash
# 接管 SSH 客户端配置并连接 1Password SSH Agent。
# 私钥导入、Agent 开关和旧私钥删除必须由用户在确认连接正常后手动完成。
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
SSH_LOCAL="$SSH_DIR/config.local"
REPO_CONFIG="$ROOT/stow/ssh/.ssh/config"
AGENT_SOCKET="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
BACKUP_ROOT="${DOTFILE_BACKUP_DIR:-$HOME/dotfile_bak}"

[ -d "/Applications/1Password.app" ] || die "1Password.app 未安装；先完成 README 的手动步骤"
have op || die "1Password CLI 未安装；先跑 'make core'"
command -v stow >/dev/null 2>&1 || die "stow 未安装；先跑 'make core'"

op_ready || die "1Password CLI 尚未解锁；请打开 1Password 并完成 CLI 授权"
[ -S "$AGENT_SOCKET" ] || die "1Password SSH Agent 尚未开启：打开 1Password → 设置 → 开发者 → SSH Agent"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ -L "$SSH_CONFIG" ] \
   && [ "$(readlink -f "$SSH_CONFIG" 2>/dev/null)" = "$(readlink -f "$REPO_CONFIG" 2>/dev/null)" ]; then
    ok "SSH 主配置已由仓库管理"
elif [ -f "$SSH_CONFIG" ] && [ ! -L "$SSH_CONFIG" ]; then
    [ ! -e "$SSH_LOCAL" ] && [ ! -L "$SSH_LOCAL" ] \
        || die "$SSH_LOCAL 已存在；为防止覆盖，请先人工合并"

    BACKUP_DIR="$BACKUP_ROOT/$(date '+%Y%m%d-%H%M%S')-$$"
    mkdir -p "$BACKUP_DIR"
    rsync -a "$SSH_CONFIG" "$BACKUP_DIR/config"
    mv "$SSH_CONFIG" "$SSH_LOCAL"
    chmod 600 "$SSH_LOCAL"
    info "原 SSH Host 配置已迁到 $SSH_LOCAL，并备份到 $BACKUP_DIR"

    if ! stow --no-folding --dir="$ROOT/stow" --target="$HOME" --restow ssh; then
        mv "$SSH_LOCAL" "$SSH_CONFIG"
        die "SSH 配置建链失败，已恢复原文件"
    fi
    ok "SSH 主配置已链接到仓库"
elif [ ! -e "$SSH_CONFIG" ] && [ ! -L "$SSH_CONFIG" ]; then
    stow --no-folding --dir="$ROOT/stow" --target="$HOME" --restow ssh
    ok "SSH 主配置已链接到仓库"
else
    die "$SSH_CONFIG 是未识别的链接或文件类型；不会覆盖"
fi

# 重跑时也修复同一 stow 包里的 Fish SSH_AUTH_SOCK 配置。
stow --no-folding --dir="$ROOT/stow" --target="$HOME" --restow ssh \
    || die "SSH/1Password 配置建链失败"

if SSH_AUTH_SOCK="$AGENT_SOCKET" ssh-add -l >/dev/null 2>&1; then
    ok "1Password SSH Agent 已提供至少一把密钥"
else
    warn "Agent 已开启，但没有可用 SSH Key。请在 1Password 中导入或生成 SSH Key。"
fi

ok "1Password SSH Agent 集成完成"
