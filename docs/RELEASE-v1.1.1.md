# DLGDash v1.1.1：菜单选中状态更清晰

本版增强菜单选中状态，方便户外辨认当前栏目和选项，同时包含高度缺测恢复修复。

## 菜单有哪些变化

- **彩屏**：选中栏目和列表选项整行亮底黑字，左侧增加 `>` 箭头。
- **黑白屏**：选中栏目和列表选项整行反白，保留箭头。
- **保存、退出、翻页按钮**：选中时整块高亮；按确认键执行当前高亮按钮。
- 中英文均可使用，选中状态持续显示，无需修改任何设置。

下面是模拟数据画面。PA01 用户已反馈新版菜单实机使用正常，其他机型的验证状态见机型表。

![PA01 中文菜单选中效果](https://raw.githubusercontent.com/SailTechnology/DLGDash/v1.1.1/docs/images/pa01-menu.png)

![黑白屏中文菜单选中效果](https://raw.githubusercontent.com/SailTechnology/DLGDash/v1.1.1/docs/images/gx12-menu.png)

## 下载与升级

1. 在下方 **Assets** 下载对应安装包：彩屏选 `DLGDash-Color-v1.1.1.zip`；黑白屏选 `DLGDash-Monochrome-v1.1.1.zip`。只选一种，不用 Source code 代替安装包。
2. 飞机断电，将遥控器以 USB 存储方式连接电脑，完整备份内容盘。
3. 解压 ZIP，将 **SD 文件夹里面的内容**复制到遥控器内容盘根目录，合并文件夹并覆盖插件文件。保留自己的 `MODELS`、`RADIO` 和 `WIDGETS/DLGDash/profiles`。
4. 清理本插件的旧编译缓存：`WIDGETS/DLGDash` 内的 `.luac`、`SCRIPTS/TOOLS/DLGSetup.luac`，以及黑白屏的 `SCRIPTS/TELEMETRY/DLG.luac`。没有则跳过，不删 `.lua` 源码或其他插件文件。
5. 安全弹出、拔线并重启，打开 DLG Setup，移动栏目、进入选项列表，再移动到保存和退出，检查高亮跟随选择。

包内 `README.md` 是安装教程，`UPDATE.md` 是本页说明。机型范围与 v1.1 相同；[机型表](https://github.com/SailTechnology/DLGDash/blob/v1.1.1/docs/RADIOS.md) · [彩屏保姆教程](https://github.com/SailTechnology/DLGDash/blob/v1.1.1/docs/INSTALL-COLOR.md) · [黑白屏保姆教程](https://github.com/SailTechnology/DLGDash/blob/v1.1.1/docs/INSTALL-MONO.md)。不需要为了本次更新刷固件。

## 发射高度设置

想记录 Zoom 内及退出后一段时间的最高高度，在 **DLG Setup → 第 3 页“发射”**选择 **Zoom → 退出后延迟（例如 2.0 秒）→ 阶段峰值 / Peak: mode + delay**，然后保存。延迟可调 0～10 秒，0 秒表示退出 Zoom 就结算。

断续回传时保留已收到的峰值；`~52.7` 表示记录不完整，实际最高点可能更高。没有可用结果时显示等待，恢复后首个读数标为 `>52.7`，表示延后读数，不能当作准确发射峰值。下一次进入所选模式重新记录。[完整说明](https://github.com/SailTechnology/DLGDash/blob/v1.1.1/scripts/edgetx/DLGDash/README.md)。

本次菜单优化不改变曲线、声音、模型混控或已有参数。彩屏／黑白屏中英文、设置保存、旧固件和受限内存离线检查通过；PA01 菜单实机使用已获正常反馈，其他机型仍需地面验证。在控制链路可靠的前提下，尽可能提高 **ELRS 有效遥测回报率**。
