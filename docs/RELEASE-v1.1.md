# DLGDash v1.1

本版扩展常见 EdgeTX 遥控器，仍然只提供两个安装包。新机型为实验适配，发布版本号不代表每一台遥控器均已实测。

## 下载哪个

| 安装包 | 遥控器 |
| --- | --- |
| **DLGDash-Color-v1.1.zip** | PA01；HelloRadio V12 / CNC MAX、V15 系列、V16；RadioMaster TX16S 一代 / 二代 / MK3、TX15、GX15；Flysky PL18 / EV / U；Jumper T15 / Pro、T16、T18；FrSky X10 / X12S |
| **DLGDash-Monochrome-v1.1.zip** | RadioMaster Boxer、Pocket、TX12 / MKII、GX12、Zorro；HelloRadio V14 LCD / OLED；Jumper T14、T12、T20、T-Pro、T-Lite 系列；FrSky X9D、X9E、X7、X9 Lite、X-Lite 系列 |

下载下方 Assets 中对应的 ZIP，**不要下载 Source code**，不要叠加安装两个包。Zorro 不需要专用包。

[完整机型及验证状态](https://github.com/SailTechnology/DLGDash/blob/v1.1/docs/RADIOS.md)

## 本版变化

- 纳入 46 个固件机型标识，扩展 RadioMaster、HelloRadio、Jumper 和 Flysky 常见型号。
- 新增 TX16S MK3 的 800×480 布局与大号中文；GX15 / TX15 使用 480×320 布局。
- HelloRadio V12 MAX 使用 v12 小彩屏配置，V15 使用 480×272 配置，V14 LCD 与 OLED 均使用黑白屏包。
- 保留 V16 旧固件绘图兼容修复、黑白屏分段加载设置和缺少 table 库时的保存兼容。
- 新增大屏资源只在彩屏包中，不增加黑白屏的字体负担。

## 第一次安装

1. 飞机断电，遥控器开机；在 SYS → VERSION 确认系统是 **EdgeTX**。ELRS 版本不是遥控器系统版本。
2. 遥控器连接电脑，选择 USB 存储。把包含 MODELS、RADIO、SCRIPTS 的整个内容盘备份到电脑，确认备份能打开。
3. 下载对应安装包并解压，打开其中的 **SD 文件夹**。
4. 把 SD **里面的内容**复制到遥控器内容盘根目录。不要把整个 SD 文件夹套一层复制进去，也不要复制到固件升级盘。
5. 安全弹出，拔线，重启遥控器。
6. 彩屏：主屏设置中选 1×1 布局，关闭不需要的显示栏，添加 DLGDash；不要求 App Mode。黑白屏：当前模型的 Display 页面选 Script → DLG。
7. 通过 SYS → 工具 → DLG Setup 打开设置，选择本模型的 RxBt、高度、计时器、Zoom 结束模式、四 / 六舵机通道以及声音与清曲线开关。不会替你猜测开关绑定。
8. 保存后退出并重新进入，确认设置保留。接收机上电时对照原生遥测核对数据；接收机断电时确认失联停音。

各机型按键与截图：[新手保姆教程](https://github.com/SailTechnology/DLGDash/blob/v1.1/docs/INSTALL-BEGINNER.md) · [彩屏教程](https://github.com/SailTechnology/DLGDash/blob/v1.1/docs/INSTALL-COLOR.md) · [黑白屏教程](https://github.com/SailTechnology/DLGDash/blob/v1.1/docs/INSTALL-MONO.md) · [所有设置说明](https://github.com/SailTechnology/DLGDash/blob/v1.1/scripts/edgetx/DLGDash/README.md)

## 旧版本升级

1. 先完整备份内容盘，特别保留 `WIDGETS/DLGDash/profiles` 中每个模型的配置。
2. 按上述步骤复制新包的 SD 内容并覆盖插件文件。不要覆盖或删除 MODELS、RADIO、自己的 profiles。
3. 删除 **插件自身**的旧编译缓存：`WIDGETS/DLGDash` 下的 `.luac`、`SCRIPTS/TOOLS/DLGSetup.luac`、`SCRIPTS/TELEMETRY/DLG.luac`（不存在则跳过）。不要删除其他脚本缓存或插件的 `.lua` 源文件。
4. 安全弹出并重启，遍历十页设置，改一项、保存、重进，再重启确认。曲线有数据后再次进入设置，停留两分钟并保存。
5. 四 / 六舵机均检查 ±100% 附近的显示，检查声音和清曲线按钮。黑白屏进入设置会暂停本插件记录和提示音，请在地面操作。

不需要为了本插件先刷 EdgeTX 或 ELRS。升级不修改混控、舵机方向、行程、射频和原生计时器；手动添加显示页面会保存该页面配置。

## 使用范围

PA01 有前期使用反馈，T14 用户反馈 beta.4 基本正常；其他机型包括新增型号均需实机地面验证。V16 请分别复测 SYS 和主屏入口。厂商自编译固件、首次编译及其他同时运行的脚本可能影响可用内存。

EL18 / NV14 竖屏、OpenTX、Ethos、FrOS、FlyskyOS 不在本版支持范围。不要只凭品牌或商品后缀判断适配。

在控制链路可靠的前提下，**尽可能提高 ELRS 的有效遥测回报率**；不能只看控制包速率，也不要为曲线刷新牺牲链路可靠性。电压以选中的遥测源为准，插件不替代原生低压告警或失控保护。
