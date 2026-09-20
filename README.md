# dotfile

Apple Silicon macOS 环境的一键初始化。换电脑或重装系统后，把配置、软件、字体、系统设置一次性还原。

技术栈：**GNU Stow**（软链）+ **Make**（编排）+ **1Password CLI**（密钥）+ **Homebrew**（软件）。

---

## 新机器怎么用

### 阶段 0：手动（约 10 分钟）

这几步没法自动化，`op` 要登录才能用，而登录本身需要凭据。

- [ ] 登录 Apple ID
- [ ] 装 1Password app（[下载](https://1password.com/downloads/mac/)）并登录 —— 需要**主密码 + Secret Key**，从旧机器的 1Password 里「设置 → 账户 → 设置其他设备」扫码最快
- [ ] 1Password 里打开 **设置 → 开发者 → 与 1Password CLI 集成**（否则 `op` 用不了生物解锁）
- [ ] 在同一页开启 **SSH Agent**，并把现有 SSH 私钥导入 1Password（或新建 Ed25519 key）
- [ ] 如果连 GitHub 都打不开，先手动弄个能用的代理，或者在下一步加 `GH_MIRROR=`

### 阶段 1：一条命令

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Jaschenn/dotfile/main/bootstrap.sh)"
```

GitHub 访问不了时：

```bash
GH_MIRROR=https://ghfast.top sh -c "$(curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/Jaschenn/dotfile/main/bootstrap.sh)"
```

这条命令会依次完成：

1. 装 **Xcode Command Line Tools**（弹系统对话框，点一下「安装」）
2. 克隆本仓库到 `~/dotfile`
3. 交给 `make bootstrap`：
   - **FlClash** —— 排在最前面。后面所有下载都依赖它，没代理基本寸步难行
   - **Homebrew**
   - **core 工具** —— stow / op / mas
   - **Git 配置** —— 通用行为、全局 ignore，以及本机身份的安全迁移
   - **1Password 集成** —— CLI / SSH Agent / SSH 主配置
   - **字体** —— JetBrains Mono Nerd Font / 霞鹜文楷等宽屏幕阅读版
   - **Shell / 终端** —— fish / fzf / starship / tlrc / yazi / zellij / zoxide / Ghostty
   - **开发工具** —— gh / htop / lazygit / node / pnpm / rust / uv / watchman
   - **桌面应用** —— Alfred / Chrome / Obsidian / OmniFocus / Zotero
   - **Rime / 鼠须管** —— librime / squirrel-app / Plum / 雾凇拼音 / 字号配置
   - **Vim / Rime** —— rime.vim / 独立 rime-ice / rime-query
   - **stow 建链** —— 把 `stow/` 下的配置链到 `~`

除系统安装对话框、管理员密码等 macOS 必要确认外，流程会主动暂停等待配置的
只有 FlClash 订阅导入（见下文「已知的手动步骤」）。

### 阶段 2：体检

```bash
cd ~/dotfile && make doctor
```

一键安装如果没有配套体检是不可信的 —— 很多失败是静默的（`defaults write` 写了个失效的 key 照样返回 0，字体装错名字只会静默回退）。`make doctor` 逐项核对：工具在不在、代理通不通、vault 能不能访问、每一个软链是不是真的指向仓库、仓库里有没有混进明文密钥或大文件。

---

## 常用命令

```
make              列出所有目标
make bootstrap    完整初始化（新机器）
make doctor       体检
make proxy-check  只测代理
make git          接管 Git 配置，并迁移本机身份
make onepassword  接通 1Password CLI 与 SSH Agent
make fonts        安装或更新 Ghostty 所需字体
make shell        安装 Shell 与终端工具
make dev          安装通用命令行开发工具
make apps         安装常用桌面应用
make rime         安装或更新 Rime、鼠须管与雾凇拼音
make vim          安装 rime.vim、独立词库并编译 rime-query

make link         比较并备份现有配置，再建立所有软链（幂等）
make unlink       拆掉所有软链（不动仓库里的文件）
make relink       拆了重链（改过目录结构后用）
make link-dry     预演，只打印不落地
```

改完配置**不需要**重新 `make link` —— stow 建的是软链，编辑仓库里的文件即刻生效。只有**新增/删除文件**或改目录结构时才要 `make relink`。

首次执行 `make link` 时，脚本会逐个比较目标文件。普通文件或指向其他位置的
链接会先备份到 `~/dotfile_bak/<日期时间>/`，再由仓库版本接管；即使内容不同也
不会静默丢失。可先运行 `make link-dry` 查看完整计划。

### 环境变量

| 变量 | 默认 | 用途 |
|---|---|---|
| `BREW_MIRROR` | 无 | `ustc` / `tuna`，brew 走国内镜像 |
| `GH_MIRROR` | 无 | 全局 GitHub 下载与 Git clone 加速前缀，如 `https://ghfast.top` |
| `PROXY_PORT` | `7890` | 本地代理端口（FlClash 的「混合端口」） |
| `TARGET` | `$HOME` | stow 的目标目录，测试时可以指到临时目录 |
| `OP_VAULT` | `dotfile` | 1Password vault 名 |
| `FLCLASH_VERSION` | latest | 钉住 FlClash 版本，如 `0.8.98` |
| `NO_PROXY_AUTODETECT` | 无 | 设任意值可关掉代理自动探测 |
| `DOTFILE_BACKUP_DIR` | `~/dotfile_bak` | Stow 接管现有配置时的备份根目录 |
| `FONT_DIR` | `~/Library/Fonts` | 用户字体安装目录 |

例：`make brew BREW_MIRROR=ustc`

---

## 1Password

脚本读取的密钥放在 vault **`dotfile`** 里，仓库中只出现 `op://` 引用。
SSH Key 保存在 1Password 的 Personal、Private、Employee 或自行配置的 vault 中，
私钥永远不写入仓库。

### 需要的条目

| 条目 | 引用 | 用途 |
|---|---|---|
| `FlClash` → `subscription` | `op://dotfile/FlClash/subscription` | `make proxy` 读出来放进剪贴板 |

> 新增密钥条目时用 `op item create`，或直接在 app 里建，字段名要和引用的最后一段对上。

### 为什么不在 shell 启动时读

`config.fish` 里写 `op read` 会让**每开一个 shell** 都走一次网络 + 生物识别，启动直接卡住。正确做法是安装期用 `op inject` 把密钥渲染进一个 gitignored 的文件（`conf.d/secrets.fish`），shell 只负责 source。

### SSH 和 git 签名

项目使用 1Password SSH Agent，仓库只保存 socket 配置，私钥不进入仓库。
现有主机配置在首次执行 `make onepassword` 时会迁到不提交的
`~/.ssh/config.local`。如果使用 1Password SSH Bookmarks，生成的配置会由
`~/.ssh/1Password/config` 自动包含。

首次接通按这个顺序操作：

1. 在 1Password 中导入现有 SSH 私钥，或新建 Ed25519 key。
2. 如果新建密钥，先把新公钥加入 GitHub 和服务器的 `authorized_keys`。
3. 1Password → 设置 → 开发者：开启 CLI 集成和 SSH Agent。
4. 运行 `make onepassword`，再用 `ssh aliyun` 等实际连接验证。
5. 从 `~/.ssh/config.local` 删除旧的 `IdentityFile` 后再次验证。
6. 全部确认正常后，才手动移走或删除磁盘上的旧私钥。

Git commit SSH 签名需要选择一把具体公钥，暂不自动配置。

---

## Git

仓库管理 `~/.config/git/config` 与全局 ignore。所有机器共享默认分支、自动清理
远端引用和首次 push 自动设置 upstream 等行为；姓名、邮箱及签名设置保存在不入库的
`~/.config/git/config.local`。

首次运行 `make git` 会把现有 `~/.gitconfig` 备份到
`~/dotfile_bak/<日期时间>/`，再迁移为 `config.local`。新机器没有可迁移身份时，运行：

```bash
git config --file ~/.config/git/config.local user.name "你的名字"
git config --file ~/.config/git/config.local user.email "你的邮箱"
```

---

## 目录结构

```
.
├── bootstrap.sh          新机器的唯一入口（POSIX sh，不能假设任何东西已装）
├── Makefile              编排层，只调度不实现
├── README.md
├── brew/
│   ├── Brewfile.apps     常用桌面应用
│   ├── Brewfile.core     dotfile 自身的依赖
│   ├── Brewfile.dev      通用命令行开发工具
│   ├── Brewfile.fonts    Homebrew 可安装的字体
│   ├── Brewfile.rime     librime 与 squirrel-app
│   └── Brewfile.shell    Shell 与终端工具
├── fonts/                霞鹜文楷等宽屏幕阅读版的版本锁与说明
├── rime/                 Rime 模块说明（雾凇由官方 Plum 管理）
├── scripts/
│   ├── lib.sh            共用函数：日志、代理探测、op 读取、下载、架构判断
│   ├── install-*.sh      各个安装步骤的实现
│   ├── setup-*.sh        模块初始化与集成
│   ├── stow-packages.sh   比较、备份并安全接管现有配置
│   ├── brew-bundle.sh    brew bundle 的薄封装
│   ├── proxy-check.sh
│   └── doctor.sh
└── stow/                 stow 的包目录，一个子目录一个包
    ├── english/.config/english/       capture.py / known.txt / build_dict.py
    ├── fish/.config/fish/             config.fish / conf.d/ / functions/
    ├── ghostty/.config/ghostty/config
    ├── git/.config/git/             config / ignore
    ├── rime/Library/Rime/squirrel.custom.yaml
    ├── ssh/.ssh/config
    ├── ssh/.config/fish/conf.d/1password-ssh-agent.fish
    ├── starship/.config/starship.toml
    ├── vim/.vimrc
    └── zellij/.config/zellij/config.kdl
```

`stow/` 下**只放会被链到 `$HOME` 的文件**。stow 不看 `.gitignore`，放进去的东西
一律会建链，所以备份文件、生成物、密钥都不能放这里。

### stow 包怎么组织

包内路径 = 相对 `$HOME` 的路径。比如让 `~/.config/ghostty/config` 生效：

```
stow/ghostty/.config/ghostty/config
```

用的是 `--no-folding`，逐个文件建链，而不是把整个包目录链过去。折叠虽然省链接数，但应用往配置目录里写的运行时文件（`fish_variables`、`fish_history`、`completions/`）会直接落进这个仓库，很脏。

### 加一个新模块

1. `stow/<模块>/...` 放配置文件
2. 需要装软件就加 `brew/Brewfile.<模块>`
3. 需要额外动作（生成二进制、跑初始化命令）就写 `scripts/setup-<模块>.sh`
4. Makefile 里加一个目标，挂到 `bootstrap` 的依赖上
5. `scripts/doctor.sh` 里加对应的检查 —— **这步别省**

---

## 已知的手动步骤

这些是 macOS 的硬约束，不是没做完。

| 步骤 | 为什么不能自动化 |
|---|---|
| 1Password 登录 | 需要主密码 + Secret Key，正是要引导的东西本身 |
| Xcode CLT 的安装对话框 | 系统弹窗，无 API |
| **FlClash 导入订阅 + 开系统代理** | FlClash 是 Flutter GUI，没有 CLI。脚本能做的只是把订阅链接从 1Password 塞进剪贴板、把 app 打开、然后等你粘贴 |
| Alfred / 输入法等的系统权限 | TCC（完全磁盘访问、辅助功能、输入监控）不关 SIP 就无法写入 |
| App Store 首次登录 | `mas` 装应用前要先在 App Store.app 里登录过 |
| 鼠须管加入输入法列表 | macOS 输入源需要用户在「系统设置 → 键盘 → 输入法」中确认 |

> 想要真正的无人值守，代理那一环得换成 `mihomo`（brew formula，纯 YAML 配置，订阅链接可以从 1Password 渲染进去，用 `brew services` 跑）。现在用 FlClash 是为了日常有个 GUI。

---

## 开发约定

- **macOS 自带 GNU Make 3.81**（2006 年的版本）。别用 `.ONESHELL`、`$(file ...)`、`!=` 赋值 —— 都是 3.82+ 才有的。多行逻辑一律放 `scripts/`，Makefile 只做编排。
- **Python 一律用 uv。** 脚本通过 PEP 723 声明依赖，并使用 `uv run --script` 执行，不在运行时调用 `pip install`。
- **一切都要幂等。** 每个目标都得能反复跑。能用真实文件当 make target 的就用（比如生成的词典库依赖构建脚本），make 会天然帮你跳过；不能的就在脚本里用 `command -v` / `brew list` 这类实际状态检查，别用 stamp 文件 —— stamp 会在你手动卸载软件后撒谎。
- **不提交生成物和个人数据。** 配置进仓库，生成物进 `~/.local/share/`，个人数据单独备份。
- **每加一个模块，同步加一条 doctor 检查。**

## 现在的进度

- [x] Makefile 编排层 + bootstrap 入口
- [x] Xcode CLT / FlClash / Homebrew / core 工具
- [x] Stow 安全接管流程 + doctor 体检
- [x] 现有配置迁入 stow 包（fish / ghostty / git / starship / vim / zellij / english）
- [x] Git 通用配置 + 本机身份迁移
- [x] **1Password 手动接通**（代码已完成；待开启 SSH Agent、导入密钥并验证）
- [x] Rime 输入法（librime / squirrel-app / Plum / 雾凇拼音 / 字号配置）
- [x] Ghostty 字体（JetBrains Mono Nerd Font + 霞鹜文楷等宽屏幕阅读版）
- [x] Vim：rime.vim / 独立 rime-ice / rime-query 自动安装
- [x] Zellij 软件与配置
- [x] Alfred workflow（偏好设置与 workflows 由 iCloud 同步）

### 补充说明

- `english/` 包有意把 Alfred 调用的脚本链接到 `~/.config/english/`；词典库和
  `review.jsonl` 仍是本机生成物，由 `.gitignore` 排除，不进入仓库。
