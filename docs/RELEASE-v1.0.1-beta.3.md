# DLGDash v1.0.1-beta.3：V16 设置兼容修复

修复 V16 设置页、数据源列表出现的 `drawFilledRectangle` / `drawText` 数字参数报错。全屏切换不再直接丢弃未保存的设置；重新进入全屏可继续草稿。保留此前的 Zorro 设置入口修复与专用包。

**V16 约 45 秒自动返回主屏的实机现象仍待复测。** 已通过模拟停留 3 分钟和中途界面切换检查，但不等于这台自编译固件已完成实机验收。

## 下载哪个

展开本页下方 **Assets**，只下载一个 ZIP：

| 遥控器 | 安装包 |
| --- | --- |
| **HelloRadio V16、PA01、X9D 系列、GX12** | **DLGDash-v1.0.1-beta.3.zip** |
| **RadioMaster Zorro** | **DLGDash-Zorro-v1.0.1-beta.3.zip** |

不要选 Source code，不需要叠加两个包。无需为了本次更新刷遥控器或 ELRS 固件。

## 从 beta.1 / beta.2 更新

1. 接收机断电，遥控器以 USB 存储模式连接电脑。完整备份内容盘，确认 MODELS、RADIO、原插件和 profiles 都在备份中。
2. 把原 `WIDGETS/DLGDash` 改名为未使用的备份名字，例如 `DLGDash-before-beta3`，不要覆盖已有备份。
3. 若有 `SCRIPTS/TOOLS/DLGSetup.luac` 或 `SCRIPTS/TELEMETRY/DLG.luac`，改成未使用的 `.bak` 名字。其他插件不动。
4. 解压新包，将 **SD 文件夹里面的内容**复制到内容盘根目录。不要把 SD 文件夹本身复制进去。
5. 只把旧插件的 `profiles` 复制回新 `WIDGETS/DLGDash`，保留各模型的插件设置。不要复制旧 Lua 或缓存回来。
6. 安全弹出并重启。已有仪表页面不需要重新添加，混控、通道、舵机方向和射频配置不需要改动。

[完整安装教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.3/docs/INSTALL-BEGINNER.md) · [Zorro 专用教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.3/docs/INSTALL-ZORRO.md)

## V16 请这样复测

1. 从主屏进入 DLGDash 全屏，按滚轮打开设置。
2. 打开“电压来源 / Voltage source”，上下滚动，选择 RxBt。分别在接收机未连接、已连接时操作。
3. 修改一项容易核对的设置并保存，退出再进，确认保存成功。
4. 再修改一项但先不保存，在设置页停留至少 **2 分钟**，确认没有自动退出。先不要切换模型或重启。
5. 若被切回主屏，重新进入全屏，检查草稿是否仍在。记录发生时间、是否退出全屏、是否出现报错。
6. 保存后，从 SYS → TOOLS → DLG Setup 再检查选源、翻页和保存。
7. 最后检查四/六路舵量、Zoom 高度结算、Preset 清曲线、提示音，以及接收机断电后的失联和停音。

旧固件音量可选跟随系统或静音；出现 MIX 时显示混控量，不是最终舵机输出。保留原生告警和失控保护。控制链路可靠、接收机兼容时，尽可能提高 ELRS 的有效遥测回传率，不要在飞行中改包率。

仍有问题请在 [Issues](https://github.com/SailTechnology/DLGDash/issues)提供安装包文件名、SYS → VERSION 照片、触发步骤和完整报错。不要公开模型备份。本版为兼容测试版，尚未完成 V16 自编译固件和 Zorro 的实机验收。
