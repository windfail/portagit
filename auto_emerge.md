# auto_emerge

`auto_emerge` 用于自动执行 Gentoo 系统更新流程，并在更新前创建根文件系统的 Btrfs snapshot。

## 流程

脚本执行顺序如下：

1. 写入启动日志
2. 检查锁文件，避免多个更新任务同时运行
3. 创建根文件系统 snapshot
4. 执行 `emaint sync`
5. 更新 `portage`
6. 执行 `emerge -uND world`
7. 执行 `emerge --depclean`
8. 执行 `systemctl daemon-reload`
9. 执行 `emerge @preserved-rebuild`
10. 执行 `revdep-rebuild`
11. 退出时删除锁文件并写入结束日志

## Snapshot

更新前会调用：

```bash
portagit-snapshot --source /
```

因此默认会为根文件系统创建 snapshot：

```text
/snapshots/snapshot-YYYY-MM-DD_HHMMSS
```

如果 snapshot 创建失败，脚本会记录错误并退出，不会继续执行系统更新。

## 日志

日志文件：

```text
/var/log/auto_update.log
```

脚本会把主要命令输出追加到该日志中。

常见日志示例：

```text
2026-05-23 09:00:00 auto update start
2026-05-23 09:10:00 auto update over
```

失败时会记录类似：

```text
auto update error : snapshot fail
auto update error : sync fail
auto update error : update portage fail
auto update error : emerge world fail
auto update error : preserved-rebuild fail
auto update error : revdep-rebuild fail
```

## 锁文件

锁文件路径：

```text
/var/lock/auto_update
```

启动时如果锁文件存在，脚本会读取其中的 PID：

- 如果对应进程仍在运行，脚本退出
- 如果对应进程不存在，删除旧锁文件并继续

脚本退出时会通过 `trap cleanup EXIT` 删除锁文件。

## 错误处理

以下步骤失败会立即退出：

- `portagit-snapshot --source /`
- `emaint sync`
- `emerge -u portage`
- `emerge -uND world`
- `emerge @preserved-rebuild`
- `revdep-rebuild`

`emerge --depclean` 失败时只记录 warning，然后继续执行后续步骤。

## 依赖

- `bash`
- `portagit-snapshot`
- `emaint`
- `emerge`
- `systemctl`
- `revdep-rebuild`

## 手动运行

```bash
auto_emerge
```

通常需要 root 权限运行。

## 查看日志

```bash
less /var/log/auto_update.log
```

## 注意事项

- 更新前会自动创建根文件系统 snapshot
- 如果已有更新任务正在运行，脚本不会重复执行
- 该脚本适用于 Gentoo 系统更新流程
- `portagit-snapshot` 需要在 `PATH` 中，或脚本中需要改为绝对路径调用
