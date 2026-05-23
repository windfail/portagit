# portagit

portagit 是一组 Gentoo 系统相关的管理脚本，主要用于 `/etc` 配置文件版本化管理、Portage 系统更新自动化，以及 Btrfs snapshot 创建和保留策略清理。

## 脚本

| 脚本 | 说明 | 文档 |
| --- | --- | --- |
| `custom-update` | 使用 git 双分支模型管理 Gentoo `/etc` 配置更新，合并 Portage 生成的 `._cfg*` 文件和用户自定义修改 | [custom-update.md](custom-update.md) |
| `auto_emerge` | 自动执行 Gentoo 更新流程，包含更新前 Btrfs snapshot、`emaint sync`、`emerge -uND world`、清理和重建 | [auto_emerge.md](auto_emerge.md) |
| `btrfs-snapshot.sh` | 为 Btrfs 文件系统创建只读 snapshot，并按时间规则清理旧 snapshot | [btrfs-snapshot.md](btrfs-snapshot.md) |
| `test-retention.sh` | 测试 `btrfs-snapshot.sh` 的 snapshot 保留策略 | [btrfs-snapshot.md](btrfs-snapshot.md) |

## 安装

```bash
make install
```

默认安装到 `/bin`：

- `/bin/custom-update`
- `/bin/auto_emerge`
- `/bin/btrfs-snapshot.sh`

可以通过 `DESTDIR` 指定安装根目录：

```bash
make install DESTDIR=/usr/local
```

## 使用示例

检查 `/etc` 下待处理的 Portage 配置更新：

```bash
custom-update -k
```

合并配置更新：

```bash
custom-update -u
```

执行 Gentoo 自动更新：

```bash
auto_emerge
```

手动创建根文件系统 snapshot：

```bash
btrfs-snapshot.sh --source /
```

## 依赖

- Gentoo Linux
- `bash`
- `git`
- `emerge` / `emaint`
- `etc-update`
- `btrfs-progs`
- `systemctl`
- `revdep-rebuild`

## 注意事项

- 多数脚本需要 root 权限运行。
- `custom-update` 默认操作 `/etc`，并假定 `/etc` 已初始化为 git 仓库。
- `auto_emerge` 会在更新前调用 `btrfs-snapshot.sh --source /`，因此 `btrfs-snapshot.sh` 需要在 `PATH` 中。
- `btrfs-snapshot.sh` 会在目标文件系统下创建 `snapshots` 目录并清理符合规则的旧 snapshot。

## License

BSD 3-Clause License
