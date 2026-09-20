# Rime / 鼠须管

这个模块只管理两件事：

1. `brew/Brewfile.rime` 安装 `librime` 与 `squirrel-app`。
2. 官方 Plum 安装并更新雾凇拼音；仓库只保存个人字号配置。

本机唯一的个人修改是候选字号 36。它曾直接写在上游的 `squirrel.yaml` 中，
现在迁移为 `stow/rime/Library/Rime/squirrel.custom.yaml`，更新雾凇时不会丢失。

`build/`、`*.userdb/`、`user.yaml` 和 `installation.yaml` 都是生成物、个人词频
或机器状态，继续留在本机，不进入仓库，也不会被脚本删除。

```bash
make rime    # 安装/更新 Rime、鼠须管、雾凇拼音与字号配置
make doctor  # 检查是否安装和部署成功
```

首次安装后仍需在 macOS「系统设置 → 键盘 → 输入法」中手动添加鼠须管。
