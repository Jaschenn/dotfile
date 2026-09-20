#!/usr/bin/env bash
# Xcode Command Line Tools —— git / make / clang 的来源，一切的前置
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

if xcode-select -p >/dev/null 2>&1; then
    ok "Command Line Tools 已安装（$(xcode-select -p)）"
    exit 0
fi

info "安装 Xcode Command Line Tools"

# 这一步会弹系统对话框，没法静默。触发之后轮询等待，比让用户自己猜要好。
xcode-select --install 2>/dev/null || true

manual "系统弹出了「安装命令行开发者工具」对话框。" \
       "点【安装】并等它跑完（几分钟，取决于网速）。" \
       "如果没看到弹窗，可能已经在装了，直接回车让脚本轮询。"

info "等待安装完成"
for _ in $(seq 1 120); do          # 最多等 20 分钟
    if xcode-select -p >/dev/null 2>&1; then
        ok "Command Line Tools 安装完成"
        exit 0
    fi
    sleep 10
done

die "等待超时。手动装好后重新运行 'make xcode'。"
