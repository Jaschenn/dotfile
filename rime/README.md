# Rime / 鼠须管

这个模块只管理两件事：

1. `brew/Brewfile.rime` 安装 `librime` 与 `squirrel-app`。
2. 官方 Plum 安装并更新雾凇拼音；仓库只保存个人配置（字号、输入记录、语法模型与纠错补丁）。

本机唯一的个人修改是候选字号 36。它曾直接写在上游的 `squirrel.yaml` 中，
现在迁移为 `stow/rime/Library/Rime/squirrel.custom.yaml`，更新雾凇时不会丢失。

`lua/input_logger.lua` 是输入记录脚本：旁听上屏文字，按句（句末标点 / 停顿超过
`idle_gap` 秒 / 超过 `max_chars` 字）写入 Obsidian 库（iCloud）的 `OS/(1)领域/(A)Life OS/RimeInputLog/YYYY-MM-DD.md`。
由 `rime_ice.custom.yaml` 挂到 processors 最前面；配置项在脚本顶部的 `CONFIG`。
它只旁听不拦截按键，ASCII 模式下直接敲的英文也会记录（`log_ascii`）。
退格会同步删掉记录里的字，删过句末会把刚写入的那句撤回；回车、方向键、
切换应用后句子就定稿。

`rime_ice.custom.yaml` 还开启了语法模型和拼写纠错 / 模糊音：
- 语法模型 `wanxiang-lts-zh-hans.gram`（约 380MB）由 `setup-rime.sh` 下载到
  `~/Library/Rime`，不进仓库；参数照抄雾凇官方 `grammar` 配方。想更新模型就删掉文件再跑 `make rime`。
- 纠错与模糊音用 `speller/algebra/+` 追加到雾凇规则末尾，不需要的哪组注释掉、重新部署即可。

`build/`、`*.userdb/`、`user.yaml` 和 `installation.yaml` 都是生成物、个人词频
或机器状态，继续留在本机，不进入仓库，也不会被脚本删除。

```bash
make rime    # 安装/更新 Rime、鼠须管、雾凇拼音与字号配置
make doctor  # 检查是否安装和部署成功
```

首次安装后仍需在 macOS「系统设置 → 键盘 → 输入法」中手动添加鼠须管。
