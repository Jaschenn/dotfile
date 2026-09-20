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
STOW_DIR    := $(DOTFILE_DIR)/stow

TARGET   ?= $(HOME)
PACKAGES := $(notdir $(wildcard $(STOW_DIR)/*))

# --no-folding：逐个文件建链，而不是把整个包目录链过去。
# 折叠虽然省链接数，但应用往配置目录里写的运行时文件（fish_variables、
# fish_history、completions/）会直接落进这个仓库，很脏。
STOW_FLAGS := --no-folding --dir=$(STOW_DIR) --target=$(TARGET)

# ══ 总入口 ════════════════════════════════════════════════════════

.PHONY: bootstrap
bootstrap: xcode proxy brew core link ## 【新机器从这里开始】完整初始化
	@echo ""
	@echo "基础环境就绪。接下来按模块装："
	@echo "  make doctor    # 先体检一遍"

# ══ 阶段 1：网络与包管理 ══════════════════════════════════════════

.PHONY: xcode
xcode: ## 安装 Xcode Command Line Tools（git/make/clang 的来源）
	@$(SCRIPTS)/install-xcode-clt.sh

.PHONY: proxy
proxy: ## 安装并配置 FlClash —— 必须先于一切网络操作
	@$(SCRIPTS)/install-flclash.sh

.PHONY: brew
brew: ## 安装 Homebrew（BREW_MIRROR=ustc|tuna 可走国内镜像）
	@$(SCRIPTS)/install-homebrew.sh

.PHONY: core
core: ## 安装 dotfile 自身依赖的工具（stow / 1password / op / mas）
	@$(SCRIPTS)/brew-bundle.sh core

# ══ 阶段 2：软链 ══════════════════════════════════════════════════

.PHONY: link
link: ## 用 stow 把 stow/ 下的所有包链到 TARGET（默认 ~）
ifeq ($(strip $(PACKAGES)),)
	@echo "  - stow/ 下还没有包，跳过"
else
	@command -v stow >/dev/null || { echo "  ✗ stow 没装，先跑 'make core'"; exit 1; }
	@for p in $(PACKAGES); do \
	    echo "==> stow $$p"; \
	    stow $(STOW_FLAGS) --restow "$$p" || exit 1; \
	done
	@echo "  ✓ 软链完成"
endif

.PHONY: unlink
unlink: ## 拆掉 stow 建的所有软链（不动仓库里的文件）
ifeq ($(strip $(PACKAGES)),)
	@echo "  - stow/ 下还没有包，跳过"
else
	@for p in $(PACKAGES); do \
	    echo "==> unstow $$p"; \
	    stow $(STOW_FLAGS) --delete "$$p" || exit 1; \
	done
endif

.PHONY: relink
relink: unlink link ## 拆了重链（改过目录结构后用）

.PHONY: link-dry
link-dry: ## 预演：只打印 stow 会做什么，不落地
	@for p in $(PACKAGES); do \
	    echo "==> [dry] $$p"; \
	    stow $(STOW_FLAGS) --restow --simulate --verbose=2 "$$p"; \
	done

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
	@echo "  BREW_MIRROR=ustc|tuna   brew 走国内镜像"
	@echo "  GH_MIRROR=https://...   GitHub 下载走加速前缀"
	@echo "  PROXY_PORT=7890         本地代理端口"
	@echo "  TARGET=\$$HOME            stow 的目标目录"
	@echo "  OP_VAULT=dotfile        1Password vault 名"
