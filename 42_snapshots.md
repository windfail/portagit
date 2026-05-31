# 42_snapshots

`42_snapshots` 是一个 `/etc/grub.d/` 脚本，在 `grub-mkconfig` 运行时被调用，
为 `portagit-snapshot` 创建的 btrfs snapshot 生成应急启动菜单条目。

## 用途

`portagit-snapshot` 在 `/snapshots/` 下创建只读 btrfs snapshot
（命名格式 `snapshot-YYYY-MM-DD_HHMMSS`）。当主系统升级后无法启动时，
可以通过 GRUB 启动菜单选择某个 snapshot 作为根文件系统启动进入应急环境。

## 工作原理

`grub-mkconfig` 会依次执行 `/etc/grub.d/` 下所有可执行脚本，把它们的输出
拼接进 `/boot/grub/grub.cfg`。`42_snapshots` 的逻辑：

1. 通过 `findmnt -no UUID /` 动态获取根文件系统 UUID。
2. 检测 `/boot` 是否为独立分区（`findmnt -no TARGET /boot` 等于 `/boot`）。
3. 扫描 `/snapshots/snapshot-*`，按 mtime 倒序排列（最新在前）。
4. 根据检测结果生成 menuentry，若无有效条目则不输出（避免空的 submenu 导致
   GRUB 语法错误）。

### `/boot` 为独立分区

当 `/boot` 挂载在独立分区（如 ext4）时，btrfs snapshot 不包含 `/boot` 内容，
内核和 initramfs 位于 `/boot` 分区。脚本：

- 从 `/boot` 分区获取 UUID 和文件系统类型，用于 GRUB 的 `search` 和 `insmod`。
- 使用 `/boot/vmlinuz` 符号链接指向的当前内核，搭配对应的 initramfs。
- `search` 定位 `/boot` 分区，内核和 initramfs 路径相对于该分区根目录。

GRUB 启动命令行：

```
search --no-floppy --fs-uuid --set=root <BOOT_UUID>
linux /vmlinuz-<ver> root=UUID=<ROOT_UUID> ro rootflags=subvol=snapshots/<name> init=/usr/lib/systemd/systemd
initrd /initramfs-<ver>.img
```

注意：snapshot 使用的是**当前** `/boot` 中的内核，而非 snapshot 创建时的内核。
如果 snapshot 创建后内核已升级，snapshot 内的内核模块可能与启动内核不匹配。
应急恢复时应优先使用较新的 snapshot。

### `/boot` 非独立分区

当 `/boot` 与 `/` 在同一 btrfs 子卷时，snapshot 包含完整的 `/boot` 内容：

- 从 `${snap}/boot/vmlinuz` 符号链接解析当时的内核版本与文件名。
- 检测 `${snap}/boot/initramfs.img`，存在则添加 `initrd` 行。
- `search` 定位根 btrfs 分区，内核路径带 `/snapshots/<name>/boot/` 前缀。

GRUB 启动命令行：

```
search --no-floppy --fs-uuid --set=root <ROOT_UUID>
linux /snapshots/<name>/boot/<vmlinuz> root=UUID=<ROOT_UUID> ro rootflags=subvol=snapshots/<name> init=/usr/lib/systemd/systemd
initrd /snapshots/<name>/boot/<initramfs>
```

- 使用 snapshot 内 `/boot` 里当时的内核文件（与 snapshot 时刻的内核模块匹配）。

### 通用

- `rootflags=subvol=snapshots/<name>` 把 snapshot 子卷挂载为根。
- 使用 `ro` 是因为 snapshot 是只读 subvolume，无法 `rw` 挂载（见下文应急转可写）。

## 刷新触发

- **自动**：`auto_emerge` 在 `portagit-snapshot` 创建 snapshot 之后立即调用
  `grub-mkconfig -o /boot/grub/grub.cfg`，刷新失败仅记录 warning 不中断流程。
- **手动**：

  ```sh
  sudo grub-mkconfig -o /boot/grub/grub.cfg
  ```

## 启动 snapshot 后的状态

- 根文件系统是 **只读** btrfs subvolume。验证：

  ```sh
  findmnt /
  # 应看到 SOURCE=...[snapshots/snapshot-YYYY-MM-DD_HHMMSS]，OPTIONS 含 ro
  btrfs property get -ts / ro
  # ro=true
  ```

- 多数 systemd 单元仍可运行，但任何写根的操作（emerge、写日志到 `/var` 等）会失败。
- `/home`、`/boot/efi` 等独立挂载点不受影响。

## 应急转可写

只读 snapshot 不能简单地 `mount -o remount,rw`。两种方案：

### 方案一：克隆出一个可写副本（推荐）

在 snapshot 启动后，或在主系统启动下：

```sh
# 在主系统 / 任意可写挂载点下操作
sudo btrfs subvolume snapshot \
    /snapshots/snapshot-YYYY-MM-DD_HHMMSS \
    /snapshots/snapshot-YYYY-MM-DD_HHMMSS-rw
```

然后修改 GRUB 启动参数（按 `e` 进入编辑），把 `rootflags=subvol=snapshots/...`
改成 `-rw` 后缀的副本子卷即可。完成应急维护后可 `btrfs subvolume delete` 清理。

### 方案二：清除只读属性（破坏 snapshot 不可变性，慎用）

只能在**主系统**启动状态下，对目标 snapshot 操作（不能对正在使用的根操作）：

```sh
sudo btrfs property set -ts /snapshots/snapshot-YYYY-MM-DD_HHMMSS ro false
```

操作后该 snapshot 不再具有"快照不可变"的语义，且 `portagit-snapshot`
的保留策略仍可能将其删除。

## 依赖

- `findmnt`（`sys-apps/util-linux`）
- `grub-mkconfig`（`sys-boot/grub`）
- `btrfs-progs`

## 安装

通过项目 `Makefile`：

```sh
make install DESTDIR=/
```

或通过 ebuild（`app-portage/portagit`）：

```sh
sudo emerge -1 app-portage/portagit
```

安装位置：`/etc/grub.d/42_snapshots`，权限 `0755`。

## 回滚

```sh
sudo rm /etc/grub.d/42_snapshots
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

同时如需停止 `auto_emerge` 自动刷新 GRUB，删除 `auto_emerge` 中 snapshot
之后的那段 `grub-mkconfig` 调用即可。

## 已知限制

- 只读 snapshot 启动后无法直接修改根文件系统，需先按上文克隆可写副本。
- 当 `/boot` 为独立分区时，snapshot 使用当前 `/boot` 中的内核而非 snapshot
  创建时的内核；若内核已升级，可能出现模块不匹配。应急时应优先选择较新的
  snapshot，或确保 `/boot` 中保留旧内核。
- 菜单条目数量等于 `/snapshots/snapshot-*` 数量；如需限制，可在脚本的
  `sorted` 数组生成后增加 `sorted=("${sorted[@]:0:N}")` 截断。
