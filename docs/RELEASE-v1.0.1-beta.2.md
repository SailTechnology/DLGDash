# DLGDash v1.0.1-beta.2：Zorro 专用测试版

修复 Zorro 在仪表中按滚轮进入设置、或打开 DLG Setup 时出现的 **`attempt to index field '_G' (a nil value)`** 报错。新增 Zorro 专用安装包和单独的更新教程。

## 下载哪个

本页下方展开 **Assets**：

| 遥控器 | 只下载对应 ZIP |
| --- | --- |
| **RadioMaster Zorro** | **DLGDash-Zorro-v1.0.1-beta.2.zip** |
| PA01、V16、X9D 系列、GX12 | DLGDash-v1.0.1-beta.2.zip |

两个包都包含本次修复，二选一，不需要叠加。不要选 Source code；SHA256SUMS.txt 仅用于校验下载。

## Zorro 如何更新

1. 接收机先断电。将遥控器设为 USB 存储，完整备份内容盘到电脑，确认 MODELS、RADIO 和原插件设置都在。
2. 将原 `WIDGETS/DLGDash` 改为未使用的备份名字，例如 `DLGDash-before-beta2`。
3. 将 `SCRIPTS/TOOLS/DLGSetup.luac`、`SCRIPTS/TELEMETRY/DLG.luac` 改为未使用的 `.bak` 名字；不存在则跳过，不处理其他插件。
4. 解压专用 ZIP，把 **SD 里面的内容**复制到内容盘根目录，不是把 SD 整个文件夹复制进去。
5. 只把旧插件的 `profiles` 复制回新的 `WIDGETS/DLGDash`，保留各模型的设置；不要把旧脚本或缓存复制回来。
6. 安全弹出、重启。已有 DLG 遥测页不需要重新添加。分别测试仪表内按滚轮进入设置和 SYS → TOOLS → DLG Setup。

[Zorro 逐步安装与更新教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.2/docs/INSTALL-ZORRO.md) · [其他机型教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.2/docs/INSTALL-BEGINNER.md)

## 地面测试

请检查：两个设置入口、中文切换、逐页打开选项、保存并重启、四/六路舵量、Zoom 结算、Preset 清曲线、提示音开关和断开接收机后停音。

无需为了安装先刷固件。旧固件提示音音量跟随系统；出现 MIX 时为混控量，不是最终舵机输出。旧固件仍需对照原生遥测，不能单独判断某个传感器是否停止更新。保留原生告警和失控保护。

在控制链路可靠、接收机兼容的前提下，尽可能提高 ELRS 的有效遥测回传率；不要在飞行中更改包率。

本地已复现并修复视频中的报错，仍需 Zorro 真机验证，不能视为飞行验收通过。仍有问题请在 [Issues](https://github.com/SailTechnology/DLGDash/issues)提供机型、SYS → VERSION 照片、安装包文件名、触发步骤和完整报错；不要公开模型备份。
