# Ghstar

单文件 shell 脚本：在终端查看 GitHub 仓库 Star。

A tiny single-file POSIX shell script to check GitHub repo stars from the terminal. Works on Termux / ZeroTermux / Ubuntu — no `jq` needed.

## 安装 / Install

```sh
# Termux / ZeroTermux
pkg install curl
# Ubuntu / Debian: apt install curl

curl -O https://raw.githubusercontent.com/deekoz2/Ghstar/main/ghstar.sh
```

或者：`git clone https://github.com/deekoz2/Ghstar.git`

## 用法 / Usage

```sh
sh ghstar.sh torvalds/linux                     # 一个仓库 / one repo
sh ghstar.sh torvalds/linux rust-lang/rust      # 批量 / batch
sh ghstar.sh https://github.com/torvalds/linux  # 完整链接 / full URL
sh ghstar.sh torvalds                           # 汇总用户全部公开仓库 / user total
```

输出示例 / Example:

```
★ torvalds/linux
  Star 256,311 · Fork 66,675 · Watch 8,547 · Issue 3
  Linux kernel source tree

👤 torvalds：公开仓库 12 个 · Star 总计 269,900
```

## 可选配置 / Optional

```sh
export GITHUB_TOKEN=ghp_xxx   # 匿名限额 60 次/时 -> 5000 次/时 (rate limit)
export GHSTAR_API=镜像地址    # 连不上 api.github.com 时换代理 / custom mirror
```

## 兼容性 / Compatibility

- ZeroTermux / Termux（`pkg install curl` 即可）
- Ubuntu / Debian 等标准 Linux（POSIX sh，dash 兼容）

## License

[MIT](LICENSE)
