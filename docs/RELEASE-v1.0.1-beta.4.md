# DLGDash v1.0.1-beta.4：彩屏 / 黑白屏兼容修复

只按彩屏、黑白屏分包，不再单独提供 Zorro 包。无需先升级 EdgeTX 或 ELRS 固件。

## 下载

展开下方 **Assets**，按屏幕下载一个包，不叠加安装：

| 机型 | 安装包 |
| --- | --- |
| PA01、HelloRadio V16 / V12 | **DLGDash-Color-v1.0.1-beta.4.zip** |
| FrSky X9D 系列、RadioMaster GX12 / Zorro、Jumper T14 | **DLGDash-Monochrome-v1.0.1-beta.4.zip** |

彩屏添加 DLGDash 控件，黑白屏在模型 Display 页面选择 Script → DLG。黑白屏包移除彩屏资源以节省内容盘空间；运行内存优化也已保留。

不要下载 Source code 代替安装包；SHA256SUMS.txt 仅供校验。旧 Zorro 专用包用户直接升级到黑白屏包。

## 本次更新

- 保留 V16 的绘图参数兼容修复，适用于仪表全屏和 SYS → DLG Setup 两个入口。beta.2 用户需要升级，不能用旧版验证修复。
- 降低黑白屏进入设置时的内存峰值，设置页逐页加载。
- 修复精简固件缺少 `table` 库时无法保存的问题，保留各模型独立设置和保存校验。
- 新增 Jumper T14 通用黑白屏、HelloRadio V12 小彩屏实验适配。
- 保留四/六舵机显示、中英文、可调曲线、发射结算和升降音调、音量设置。
- 教程补充 1×1 布局及关闭多余显示栏的步骤，不要求开启 App Mode。

黑白屏进入插件设置期间，插件暂停曲线采样、发射高度记录和升降音；退出后恢复。请在地面设置。原生模型控制、原生遥测和原生计时器不受此暂停影响。

## 旧版升级，保留模型和设置

1. 飞机断电，将遥控器接为 USB 存储。把内容盘完整备份到电脑，尤其是 MODELS、RADIO 和 WIDGETS/DLGDash/profiles。
2. 将旧 WIDGETS/DLGDash 改名为一个未使用的备份名字，例如 DLGDash-before-beta4。不要覆盖已有备份。
3. 将 SCRIPTS/TOOLS/DLGSetup.luac 和 SCRIPTS/TELEMETRY/DLG.luac 改为未使用的备份名字；没有则跳过。不修改其他插件。
4. 解压新包，把 **SD 文件夹里面的内容**复制到内容盘根目录，允许合并文件夹、替换插件入口。
5. 只将旧 DLGDash 目录里的 **profiles** 复制回新 WIDGETS/DLGDash，不把旧脚本或 `.luac` 缓存复制回来。新包的 pages 文件夹必须完整。
6. 安全弹出、拔线、重启。不要覆盖或删除 MODELS、RADIO；已有仪表页面无需重新添加。

[从零安装教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.4/docs/INSTALL-BEGINNER.md) · [Zorro 操作教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.4/docs/INSTALL-ZORRO.md) · [V12 操作教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.4/docs/INSTALL-V12.md)

## 使用前检查

- V16：分别从仪表全屏和 SYS → DLG Setup 打开设置，移动选项、打开电压源列表、修改并保存，再重新进入确认；停留至少两分钟，记录是否意外返回。
- T14 / Zorro / 其他黑白屏：测试冷启动进入设置、遍历十页、保存、返回仪表和重启后读取；积累一段曲线后再试一次。
- V12：使用滚轮和按键测试设置，不依赖触摸；核对四/六舵机映射。
- 对照原生遥测确认电压、高度、计时器；检查清曲线按钮、声音开关及提示音音量。
- 在链路稳定、符合使用需求的前提下，尽可能提高 **ELRS 遥测回报率**。不要只提高控制包速率，也不要为了刷新曲线牺牲链路稳定性。

本版通过离线功能、字体布局、安装包与低内存回归检查，仍是测试版。V16 自编译固件、T14 修复和 V12 等机型仍需真实遥控器地面验收；不承诺所有未知黑白屏、OpenTX 或 Ethos 可用。出现报错不要飞行，请在 [Issues](https://github.com/SailTechnology/DLGDash/issues)提供安装包名称、VERSION 页、入口与操作步骤及完整错误照片，**不要公开模型备份**。
