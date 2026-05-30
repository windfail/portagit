# portagit

portagit 是一组 Gentoo 系统相关的管理脚本，主要用于 `/etc` 配置文件版本化管理、Portage 系统更新自动化，以及 Btrfs snapshot 创建和保留策略清理。

## 脚本

| 脚本 | 说明 | 文档 |
| --- | --- | --- |
| `custom-update` | 使用 git 双分支模型管理 Gentoo `/etc` 配置更新，合并 Portage 生成的 `._cfg*` 文件和用户自定义修改 | [custom-update.md](custom-update.md) |
| `auto_emerge` | 自动执行 Gentoo 更新流程，包含更新前 Btrfs snapshot、刷新 GRUB 菜单、`emaint sync`、`emerge -uND world`、清理和重建 | [auto_emerge.md](auto_emerge.md) |
| `portagit-snapshot` | 为 Btrfs 文件系统创建只读 snapshot，并按时间规则清理旧 snapshot | [portagit-snapshot.md](portagit-snapshot.md) |
| `42_snapshots` | `/etc/grub.d/` 脚本，`grub-mkconfig` 时为 `portagit-snapshot` 的 snapshot 生成应急启动菜单 | [42_snapshots.md](42_snapshots.md) |
| `test-retention.sh` | 测试 `portagit-snapshot` 的 snapshot 保留策略 | [portagit-snapshot.md](portagit-snapshot.md) |

## 安装

```bash
make install
```

默认安装位置：

- `/bin/custom-update`
- `/bin/auto_emerge`
- `/bin/portagit-snapshot`
- `/etc/grub.d/42_snapshots`

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
portagit-snapshot --source /
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
- `grub` (`grub-mkconfig`)
- `findmnt` (`sys-apps/util-linux`)

## 注意事项

- 多数脚本需要 root 权限运行。
- `custom-update` 默认操作 `/etc`，并假定 `/etc` 已初始化为 git 仓库。
- `auto_emerge` 会在更新前调用 `portagit-snapshot --source /`，因此 `portagit-snapshot` 需要在 `PATH` 中。
- `auto_emerge` 在 snapshot 创建成功后会调用 `grub-mkconfig -o /boot/grub/grub.cfg` 刷新 GRUB 应急菜单，请确保 `grub` 已安装且 `/boot/grub/grub.cfg` 可写；失败仅记录 warning 不中断流程。
- `portagit-snapshot` 会在目标文件系统下创建 `snapshots` 目录并清理符合规则的旧 snapshot。
- `42_snapshots` 生成的应急菜单为只读启动（btrfs snapshot 本身只读），如需可写请参考 [42_snapshots.md](42_snapshots.md)。

## License

BSD 3-Clause License
