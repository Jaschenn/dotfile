# Fonts

Ghostty 使用两种字体：

- `JetBrainsMono Nerd Font Mono`：由 Homebrew cask 安装。
- `LXGW WenKai Mono Screen / 霞鹜文楷等宽 屏幕阅读版`：由官方 release 安装。

霞鹜字体严格使用官方项目
[`lxgw/LxgwWenKai-Screen`](https://github.com/lxgw/LxgwWenKai-Screen) 中的
`LXGWWenKaiMonoScreen.ttf`。不要替换成以下相似但不同的字体：

- `LXGWWenKaiScreen.ttf`：屏幕阅读版，但不是等宽版
- `LXGWWenKaiMono.ttf`：等宽版，但不是屏幕阅读版
- `LXGWWenKaiMonoGBScreen.ttf`：等宽屏幕阅读版，但采用 GB 字形

版本、下载地址、SHA-256 和 family 名记录在
`lxgw-wenkai-mono-screen.lock`。字体遵循上游的 SIL Open Font License 1.1；
本仓库不重新分发 25 MiB 的字体文件，只保存可验证的安装方法。

```bash
make fonts   # 安装或更新字体
make doctor  # 检查文件校验和与字体 family
```
