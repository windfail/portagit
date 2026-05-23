# btrfs-snapshot.sh

`btrfs-snapshot.sh` 用于为指定 Btrfs 文件系统创建只读 snapshot，并按时间规则清理旧 snapshot。

## 用法

```bash
btrfs-snapshot.sh [--source PATH] [--dry-run] [--plan-retention] [--now "YYYY-MM-DD HH:MM:SS"]
```

## 选项

| 选项 | 说明 |
| --- | --- |
| `--source PATH` | 指定要创建 snapshot 的源文件系统，默认是 `/` |
| `--dry-run` | 只打印将要创建或删除的 snapshot，不实际执行 Btrfs 操作，也不创建目录 |
| `--plan-retention` | 测试保留策略用：从 stdin 读取 snapshot 路径，只输出应删除的 snapshot |
| `--now "YYYY-MM-DD HH:MM:SS"` | 配合 `--plan-retention` 使用，固定当前时间，便于测试 |
| `-h`, `--help` | 显示帮助 |

## Snapshot 路径规则

snapshot 目录固定放在源文件系统路径下的 `snapshots` 目录中。

| Source | Snapshot 目录 | Snapshot 示例 |
| --- | --- | --- |
| `/` | `/snapshots` | `/snapshots/snapshot-2026-03-01_000000` |
| `/home` | `/home/snapshots` | `/home/snapshots/snapshot-2026-03-01_000000` |

snapshot 名称格式：

```text
snapshot-YYYY-MM-DD_HHMMSS
```

## 示例

为根文件系统创建 snapshot：

```bash
btrfs-snapshot.sh --source /
```

为 `/home` 创建 snapshot：

```bash
btrfs-snapshot.sh --source /home
```

预览将要执行的操作：

```bash
btrfs-snapshot.sh --source /home --dry-run
```

## 保留策略

脚本按以下规则清理 snapshot：

1. 最近 30 天内的 snapshot：保留
2. 30 天到 180 天内的 snapshot：查看最新的两个 snapshot，如果间隔小于 30 天，删除最新的那个 snapshot
3. 超过 180 天的 snapshot：删除

当前参数：

```bash
RECENT_DAYS=30
ARCHIVE_DAYS=180
MIN_ARCHIVE_INTERVAL_DAYS=30
```

## 测试保留策略

`--plan-retention` 不访问 Btrfs，也不操作真实文件系统。它从 stdin 读取 snapshot 路径，并输出根据保留策略应该删除的路径。

示例：

```bash
printf '%s\n' \
  /snapshots/snapshot-2026-04-20_000000 \
  /snapshots/snapshot-2026-04-01_000000 \
| btrfs-snapshot.sh --plan-retention --now "2026-05-23 00:00:00"
```

输出：

```text
/snapshots/snapshot-2026-04-20_000000
```

也可以运行仓库中的测试脚本：

```bash
./test-retention.sh
```

## 依赖

- `bash`
- `btrfs`
- GNU `date`
- `find`
- `sort`

## 注意事项

- 实际运行时需要有权限执行 `btrfs subvolume snapshot` 和 `btrfs subvolume delete`
- `--dry-run` 可用于检查目标路径和删除计划，不会执行 Btrfs 操作
- snapshot 名称必须符合 `snapshot-YYYY-MM-DD_HHMMSS` 格式，否则会被跳过
