# 机型与安装包

只分 **Color 彩屏包**、**Monochrome 黑白屏包**，不用按品牌下载专用版。以下扩展机型使用 beta.5，不要求为了插件刷固件。

## 彩屏

| 机型 | 屏幕 | 操作 |
| --- | --- | --- |
| Flysky PA01 | 320×240 | 彩屏主屏添加 DLGDash |
| HelloRadio V12 | 320×240 | 彩屏主屏添加 DLGDash，滚轮操作 |
| HelloRadio V16 | 480×272 | 彩屏主屏添加 DLGDash |
| RadioMaster / Eachine TX16S、MAX、Mark II | 480×272 | 彩屏主屏添加 DLGDash；不含 MK3 |
| RadioMaster TX15 | 480×320 | 实验适配，按 EdgeTX 2.12 接口模拟；厂商自编译固件仍需复测 |
| Flysky PL18U、Jumper T15 | 480×320 | 彩屏主屏添加 DLGDash；PL18U 必须运行 EdgeTX |
| Jumper T16、T18 系列 | 480×272 | 彩屏主屏添加 DLGDash |
| FrSky Horus X10 / X10S、Express 系列、X12S | 480×272 | 必须运行 EdgeTX，不适用于 Ethos / FrOS |

使用 [Color 安装教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.5/docs/INSTALL-COLOR.md)。优先选择 1×1 布局，关闭不需要的显示栏，不要求 App Mode。非触摸机型使用按键和滚轮；设置可以从 SYS → 工具 → DLG Setup 打开。

## 黑白屏

| 机型 | 屏幕 |
| --- | --- |
| RadioMaster Boxer、Pocket、TX12 / TX12 MKII、GX12、Zorro | 128×64 |
| HelloRadio V14（LCD / OLED） | 128×64 |
| Jumper T12 系列 / T12 MAX、T14、T20 / T20 V2、T-Pro / V2 / S、T-Lite（含 F4 版本） | 128×64 |
| FrSky Q X7 / Q X7 Access、X9 Lite / S、X-Lite / S / Pro | 128×64 |
| FrSky X9D / Plus / Plus 2019、X9E | 212×64 |

使用 [Monochrome 安装教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.5/docs/INSTALL-MONO.md)。在当前模型 Display 页面选择 Script → DLG，不是在彩屏控件菜单寻找插件。

滚轮机型：转动切换选项，按下确认，RTN / EXIT 返回。方向键机型：用上一项 / 下一项键移动，ENTER 确认；菜单翻页使用固件对应的 PAGE 键。按键名称不同，以当前 EdgeTX 的导航键为准。不要为了套教程改模型的开关绑定。

黑白屏设置期间，插件曲线、发射记录和提示音暂停；请在地面设置。原生模型控制和原生计时器不会因此暂停。

## 验证状态

- PA01：已有使用反馈，更新后仍需检查。
- T14：2026-09-08 用户反馈 beta.4 基本正常；这不是飞行安全认证，也不代表其他机型已经实测。
- V16：有早期报错及修复记录，仍需确认新版 SYS / 主屏两个入口。
- 其余表内机型：实验适配，通过对应屏幕和机型标识的离线回归后仍须实机地面检查。模拟按键事件不等同于每台真机按键已经验证。

尚未纳入本轮：TX16S MK3、GX15、HelloRadio V12 MAX / V15、Jumper T15 Pro、Flysky PL18 / EL18 / NV14 等其他变体、竖屏或新架构机型。不要因为名称接近或同是彩屏就直接套用本表。OpenTX、Ethos、FrOS、FlyskyOS 不在承诺范围；只有明确运行 EdgeTX 并提供 Lua 功能的固件才能试用。

PA01 是 320×240，TX16S 一代 / 二代是 480×272，PL18U 在 EdgeTX 下是 480×320 横屏，EL18 是 320×480 竖屏。不能都按 480×320 处理。

## 会不会越来越占内存

不会为每个型号各装一份程序。黑白屏共用程序，彩屏按实际屏幕尺寸排版；只加载当前需要的界面和设置页。机型清单、测试程序不会装进遥控器。

下载 ZIP 的大小、解压后的内容盘占用、Lua 运行内存是三回事。新机型增多不代表 Lua 内存同比增加；黑白屏包不带彩屏字体和绘图代码。但旧固件、其他同时运行的脚本及首次编译仍可能占用内存，因此不能保证任何机型都不会报 `not enough memory`。

旧版备份留在内容盘上仍会占空间。确认电脑备份完整并完成新版地面验收后，可把旧插件备份移出内容盘；不要删除 MODELS、RADIO 或当前 profiles。

## 第一次在新机型试用

1. 飞机断电，拍下 SYS → VERSION 页，记录机型、EdgeTX 版本及包名。
2. 备份全部内容盘。升级时保留 profiles，不带回旧脚本和 `.luac`；步骤见对应安装教程。
3. 添加仪表后，选择本模型自己的 RxBt、高度源、计时器和四 / 六舵机通道。
4. 声音和清曲线开关默认不替你猜选；逐项绑定并在地面试按。
5. 遍历十页设置，修改一项并保存，退出、重新进入，再重启确认仍然保存。
6. 对照原生遥测核对电压、高度；接收机断电时确认失联停音。不要拿插件显示代替原生电压告警。
7. 累积曲线后再打开设置，停留两分钟并保存，检查内存报错和意外退出。四 / 六舵机在 ±100% 附近也检查一次。
8. 回报机型、固件版本、菜单入口与上述结果；如报错，附完整照片，不公开模型备份。

在链路稳定的前提下尽可能提高 **ELRS 有效遥测回报率**，不要只提高控制包速率；不要为曲线刷新牺牲控制链路可靠性。

## 机型资料

屏幕分组与机型名称核对依据：[EdgeTX 官方机型列表](https://edgetx.org/supportedradios/)、[2.11.3 固件目标](https://github.com/EdgeTX/edgetx/blob/v2.11.3/fw.json)、[黑白屏尺寸定义](https://github.com/EdgeTX/edgetx/blob/v2.11.3/radio/src/targets/taranis/board.h)、[Horus 屏幕定义](https://github.com/EdgeTX/edgetx/blob/v2.11.3/radio/src/targets/horus/hal.h)、[PL18U / EL18 定义](https://github.com/EdgeTX/edgetx/blob/v2.11.3/radio/src/targets/pl18/hal.h)、[TX15 官方规格](https://radiomasterrc.com/products/tx15-radio-controller-elrs-m2)。EdgeTX 官方支持某机型不等于 DLGDash 已完成该机型实测。
