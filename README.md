# dotfile

macOS 环境的一键初始化。换电脑或重装系统后，把配置、软件、字体、系统设置一次性还原。

技术栈：**GNU Stow**（软链）+ **Make**（编排）+ **1Password CLI**（密钥）+ **Homebrew**（软件）。

---

## 新机器怎么用

### 阶段 0：手动（约 10 分钟）

这几步没法自动化，`op` 要登录才能用，而登录本身需要凭据。

- [ ] 登录 Apple ID
- [ ] 装 1Password app（[下载](https://1password.com/downloads/mac/)）并登录 —— 需要**主密码 + Secret Key**，从旧机器的 1Password 里「设置 → 账户 → 设置其他设备」扫码最快
- [ ] 1Password 里打开 **设置 → 开发者 → 与 1Password CLI 集成**（否则 `op` 用不了生物解锁）
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
   - **core 工具** —— stow / 1password / op / mas
   - **stow 建链** —— 把 `stow/` 下的配置链到 `~`

中途只有一处需要你动手：FlClash 的订阅导入（见下文「已知的手动步骤」）。

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

make link         建立所有软链（幂等，可反复跑）
make unlink       拆掉所有软链（不动仓库里的文件）
make relink       拆了重链（改过目录结构后用）
make link-dry     预演，只打印不落地
```

改完配置**不需要**重新 `make link` —— stow 建的是软链，编辑仓库里的文件即刻生效。只有**新增/删除文件**或改目录结构时才要 `make relink`。

### 环境变量

| 变量 | 默认 | 用途 |
|---|---|---|
| `BREW_MIRROR` | 无 | `ustc` / `tuna`，brew 走国内镜像 |
| `GH_MIRROR` | 无 | GitHub 下载的加速前缀，如 `https://ghfast.top` |
| `PROXY_PORT` | `7890` | 本地代理端口（FlClash 的「混合端口」） |
| `TARGET` | `$HOME` | stow 的目标目录，测试时可以指到临时目录 |
| `OP_VAULT` | `dotfile` | 1Password vault 名 |
| `FLCLASH_VERSION` | latest | 钉住 FlClash 版本，如 `0.8.98` |
| `NO_PROXY_AUTODETECT` | 无 | 设任意值可关掉代理自动探测 |

例：`make brew BREW_MIRROR=ustc`

---

## 1Password

所有密钥放在 vault **`dotfile`** 里，仓库中只出现 `op://` 引用，永远不出现密文或明文。

### 需要的条目

| 条目 | 引用 | 用途 |
|---|---|---|
| `FlClash` → `subscription` | `op://dotfile/FlClash/subscription` | `make proxy` 读出来放进剪贴板 |

> 后续模块会往这张表里加。加条目时用 `op item create`，或直接在 app 里建，字段名要和引用的最后一段对上。

### 为什么不在 shell 启动时读

`config.fish` 里写 `op read` 会让**每开一个 shell** 都走一次网络 + 生物识别，启动直接卡住。正确做法是安装期用 `op inject` 把密钥渲染进一个 gitignored 的文件（`conf.d/secrets.fish`），shell 只负责 source。

### SSH 和 git 签名

用 1Password SSH Agent，私钥不落盘。`~/.ssh/config` 里那行 `IdentityAgent` 本身不是秘密，可以直接进仓库。

---

## 目录结构

```
.
├── bootstrap.sh          新机器的唯一入口（POSIX sh，不能假设任何东西已装）
├── Makefile              编排层，只调度不实现
├── README.md
├── brew/
│   └── Brewfile.core     dotfile 自身的依赖。各模块的软件放 Brewfile.<模块>
├── scripts/
│   ├── lib.sh            共用函数：日志、代理探测、op 读取、下载、架构判断
│   ├── install-*.sh      各个安装步骤的实现
│   ├── brew-bundle.sh    brew bundle 的薄封装
│   ├── proxy-check.sh
│   └── doctor.sh
└── stow/                 stow 的包目录，一个子目录一个包
    ├── english/.config/english/       capture.py / known.txt / build_dict.py
    ├── fish/.config/fish/             config.fish / conf.d/ / functions/
    ├── ghostty/.config/ghostty/config
    ├── git/.config/git/ignore
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

> 想要真正的无人值守，代理那一环得换成 `mihomo`（brew formula，纯 YAML 配置，订阅链接可以从 1Password 渲染进去，用 `brew services` 跑）。现在用 FlClash 是为了日常有个 GUI。

---

## 开发约定

- **macOS 自带 GNU Make 3.81**（2006 年的版本）。别用 `.ONESHELL`、`$(file ...)`、`!=` 赋值 —— 都是 3.82+ 才有的。多行逻辑一律放 `scripts/`，Makefile 只做编排。
- **一切都要幂等。** 每个目标都得能反复跑。能用真实文件当 make target 的就用（比如生成的词典库依赖构建脚本），make 会天然帮你跳过；不能的就在脚本里用 `command -v` / `brew list` 这类实际状态检查，别用 stamp 文件 —— stamp 会在你手动卸载软件后撒谎。
- **不提交生成物和个人数据。** 配置进仓库，生成物进 `~/.local/share/`，个人数据单独备份。
- **每加一个模块，同步加一条 doctor 检查。**

## 现在的进度

- [x] Makefile 编排层 + bootstrap 入口
- [x] Xcode CLT / FlClash / Homebrew / core 工具
- [x] stow 建链 + doctor 体检
- [x] 现有配置迁入 stow 包（fish / ghostty / git / starship / vim / zellij / english）
- [ ] **1Password 打通**（密钥注入、SSH Agent）← 下一步
- [ ] Rime 输入法
- [ ] Ghostty：字体安装（`font-jetbrains-mono-nerd-font` 有 cask；配置里用到的
      「霞鹜文楷等宽 屏幕阅读版」需要确认是哪个 cask，可能得手动下）
- [ ] Vim：`vim-plug` 安装 + `PlugInstall`
- [ ] Zellij
- [ ] Alfred（含 english 生词捕获 workflow）
- [ ] macOS 系统默认项

### 迁入 stow 时留下的待办

- `fish/conf.d/abbr.fish` 里硬编码了 `/Users/jaschen/...`，是失效路径，
  等 fish 模块时参数化掉
- `english/` 三个文件现在整体作为一个包链过去。`build_dict.py` 其实是构建脚本
  而不是配置，词典库和 `review.jsonl` 是生成物与个人数据 —— 等 Alfred 模块时
  再拆分（代码留仓库、数据去 `~/.local/share/`）
- `~/.config/git/` 目前只有 `ignore`，没有 `gitconfig`。用户名/邮箱按机器
  （work / personal）不同，需要一个 include 的本地覆盖文件
