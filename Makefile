# dotfile —— 换机器 / 重装系统后的环境初始化
#
#   make            列出所有可用目标
#   make bootstrap  从零开始跑完整套流程
#   make doctor     体检：该装的装了没、该链的链了没
#
# 注意：macOS 自带的是 GNU Make 3.81，别在这里用新语法
#（没有 .ONESHELL、没有 $(file ...)、没有 != 赋值）。
# 多行逻辑一律放进 scripts/ 里，Makefile 只做编排。

SHELL := /bin/bash
.DEFAULT_GOAL := help

# 并行会打乱顺序，而这里的顺序（代理 → brew → 其余）是有意义的
.NOTPARALLEL:

DOTFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SCRIPTS     := $(DOTFILE_DIR)/scripts
BREWDIR     := $(DOTFILE_DIR)/brew
TARGET   ?= $(HOME)

# ══ 总入口 ════════════════════════════════════════════════════════

.PHONY: bootstrap
bootstrap: xcode proxy brew core git onepassword fonts shell dev apps rime vim link ## 【新机器从这里开始】完整初始化
	@echo ""
	@echo "基础环境就绪。接下来按模块装："
	@echo "  make doctor    # 先体检一遍"

# ══ 阶段 1：网络与包管理 ══════════════════════════════════════════

.PHONY: xcode
xcode: ## 安装 Xcode Command Line Tools（git/make/clang 的来源）
	@$(SCRIPTS)/install-xcode-clt.sh

.PHONY: proxy
proxy: ## 配置代理（PROXY_MODE=none|install|full，交互时可选）
	@$(SCRIPTS)/install-flclash.sh

.PHONY: brew
brew: ## 安装 Homebrew（BREW_MIRROR=ustc|tuna 可走国内镜像）
	@$(SCRIPTS)/install-homebrew.sh

.PHONY: core
core: ## 安装 dotfile 自身依赖的工具（stow / op / mas）
	@$(SCRIPTS)/brew-bundle.sh core

.PHONY: git
git: core ## 接管 Git 通用配置，并迁移本机身份到 config.local
	@$(SCRIPTS)/setup-git.sh

.PHONY: onepassword
onepassword: core ## 接通 1Password CLI 与 SSH Agent，并安全迁移 SSH 配置
	@$(SCRIPTS)/setup-1password.sh

# ══ 字体 ══════════════════════════════════════════════════════════

.PHONY: fonts
fonts: brew ## 安装 Ghostty 所需的 JetBrains Mono 与霞鹜文楷等宽屏幕阅读版
	@$(SCRIPTS)/brew-bundle.sh fonts
	@$(SCRIPTS)/install-fonts.sh

# ══ Shell / 开发工具 / 桌面应用 ═══════════════════════════════════

.PHONY: shell
shell: brew ## 安装 Fish、Ghostty、Starship、Yazi、Zellij 等 Shell 工具
	@$(SCRIPTS)/brew-bundle.sh shell
	@$(SCRIPTS)/setup-fish.sh

.PHONY: dev
dev: brew ## 安装通用命令行开发工具
	@$(SCRIPTS)/brew-bundle.sh dev

.PHONY: apps
apps: brew ## 安装常用桌面应用
	@$(SCRIPTS)/brew-bundle.sh apps

# ══ Rime / 鼠须管 ════════════════════════════════════════════════

.PHONY: rime
rime: brew core ## 安装 Rime、鼠须管、雾凇拼音与个人配置
	@$(SCRIPTS)/brew-bundle.sh rime
	@$(SCRIPTS)/setup-rime.sh

.PHONY: vim
vim: shell rime ## 安装 rime.vim、独立输入方案并编译 rime-query
	@$(SCRIPTS)/setup-vim.sh

# ══ 阶段 2：软链 ══════════════════════════════════════════════════

.PHONY: link
link: ## 比较并备份现有配置，再用 stow 接管（幂等）
	@TARGET="$(TARGET)" $(SCRIPTS)/stow-packages.sh link

.PHONY: unlink
unlink: ## 拆掉 stow 建的所有软链（不动仓库里的文件）
	@TARGET="$(TARGET)" $(SCRIPTS)/stow-packages.sh unlink

.PHONY: relink
relink: unlink link ## 拆了重链（改过目录结构后用）

.PHONY: link-dry
link-dry: ## 预演：比较现有配置，只打印备份与接管计划
	@TARGET="$(TARGET)" $(SCRIPTS)/stow-packages.sh dry-run

# ══ 体检 ══════════════════════════════════════════════════════════

.PHONY: doctor
doctor: ## 检查环境是否符合预期
	@TARGET="$(TARGET)" $(SCRIPTS)/doctor.sh

.PHONY: proxy-check
proxy-check: ## 只测代理通不通
	@$(SCRIPTS)/proxy-check.sh

# ══ help ══════════════════════════════════════════════════════════

.PHONY: help
help:
	@echo "dotfile —— $(DOTFILE_DIR)"
	@echo ""
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | sort \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "常用变量："
	@echo "  PROXY_MODE=none|install|full  代理：不开 / 仅装 / 装+开代理（默认交互选，回车=full）"
	@echo "  BREW_MIRROR=ustc|tuna   brew 走国内镜像"
	@echo "  GH_MIRROR=https://...   GitHub 下载走加速前缀"
	@echo "  PROXY_PORT=7890         本地代理端口"
	@echo "  TARGET=\$$HOME            stow 的目标目录"
	@echo "  OP_VAULT=dotfile        1Password vault 名"
