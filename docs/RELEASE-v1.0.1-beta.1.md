# DLGDash v1.0.1-beta.1 兼容测试版

新增 RadioMaster Zorro 旧固件兼容测试，重点处理 EdgeTX 2.7.1 打开 DLG Setup 时的内存不足问题。无需为了测试先刷固件。此版可公开下载，但尚待 Zorro 真机验证，请先完成地面检查。

## 下载哪个文件

在本页下方展开 **Assets**，下载 **DLGDash-v1.0.1-beta.1.zip**。这是完整安装包，包含插件、中英文语言包、安装教程及界面示例。

不要下载 Source code 来代替安装包。SHA256SUMS.txt 仅用于校验下载文件。

## 本次更新

- 加入 Zorro 及旧版 EdgeTX 的兼容处理，降低黑白屏设置菜单的内存占用。
- 保留 PA01、HelloRadio V16、FrSky X9D 系列和 RadioMaster GX12 的安装方式。
- 重新整理安装与设置教程，按操作顺序说明备份、复制、添加页面、保存、检查和排错。

## 安装或更新

1. 先把遥控器内容盘完整备份到电脑，确认 MODELS、RADIO 和原有 DLGDash 设置都已保存。
2. 解压 ZIP，将 **SD 文件夹里面的内容**合并到遥控器内容盘根目录，不要把 SD 整个文件夹放进去。
3. 更新时保留 `WIDGETS/DLGDash/profiles`。只替换插件文件，不覆盖模型或 RADIO。
4. 已备份后，移除 DLGDash 内与更新 Lua 同名的旧 `.luac` 缓存，以及对应的 `DLGSetup.luac`、`DLG.luac`；不要清理其他插件文件。
5. 安全弹出并重启。黑白屏在模型的 Display 页面选择 **Script → DLG**；彩屏添加 **DLGDash** 控件。
6. 从系统 TOOLS 打开 **DLG Setup**，设置当前模型的数据源、模式、通道和按钮，最后选择 **Save / 保存**。

[完整图文安装教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.1/docs/INSTALL-BEGINNER.md) · [逐项设置说明](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.1/scripts/edgetx/DLGDash/README.md)

## 旧固件需要注意

- 提示音音量跟随遥控器系统设置，插件内可选跟随系统或静音。
- 舵量页面出现 **MIX** 时表示混控量，未包含最终行程限制和输出反向，不是实际舵角。不要为了匹配数字修改舵机方向。
- 无法单独判断某个传感器是否停止更新，必须核对原生遥测。接收机断电后，插件应显示失联并停音。
- 部分旧版彩屏固件会回退英文；黑白屏可选择中文设置。
- 本次面向 EdgeTX；OpenTX、Ethos 尚未验证。ELRS 固件版本不能代替 EdgeTX 系统版本。

## 帮助测试

请先在地面检查：打开 DLG Setup、切换中文、保存并重启、四/六路舵量、计时器、Zoom 结算、Preset 清曲线，以及接收机断电后停音。保留原来的低压告警和失控保护。测试版不能视为实机验收通过。

在控制链路可靠、接收机兼容的前提下，尽可能提高 ELRS 的有效遥测回传率；不要在飞行中更改包率。

发现问题时请在 [Issues](https://github.com/SailTechnology/DLGDash/issues) 提供机型、EdgeTX 完整版本、操作步骤和完整报错照片或短视频。不要公开上传整盘模型备份。

原 [v1.0](https://github.com/SailTechnology/DLGDash/releases/tag/v1.0) 保持不变；需要回退时优先恢复自己的安装前插件备份，不需要重新刷固件。
