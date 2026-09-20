#!/usr/bin/env bash
# Homebrew —— 除 FlClash 外所有软件的来源
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

if load_brew; then
    ok "Homebrew 已安装（$(brew --version | head -1)）"
else
    use_proxy_if_available

    info "安装 Homebrew"

    # 直连不通时的兜底：用国内镜像装。BREW_MIRROR=ustc 或 tuna
    case "${BREW_MIRROR:-}" in
        ustc)
            export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
            export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
            export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
            export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
            info "使用 USTC 镜像"
            ;;
        tuna)
            export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
            export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
            export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
            export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
            info "使用 TUNA 镜像"
            ;;
        '') ;;
        *)  die "未知的 BREW_MIRROR='$BREW_MIRROR'，可选 ustc / tuna" ;;
    esac

    # NONINTERACTIVE 让官方脚本不要停下来等回车（sudo 密码还是要输）
    INSTALL_URL="$(gh_url 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh')"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$INSTALL_URL")" \
        || die "Homebrew 安装失败。代理没开的话先 'make proxy'；还不行试 'make brew BREW_MIRROR=ustc'"

    load_brew || die "装完了但 PATH 里还是找不到 brew，检查 $(brew_prefix)/bin/brew"
    ok "Homebrew 安装完成"
fi

# brew 自己的网络开关：analytics 关掉（少一次外连），自动更新关掉（每条命令都卡几十秒）
brew analytics off >/dev/null 2>&1 || true

ok "brew --prefix = $(brew --prefix)"
