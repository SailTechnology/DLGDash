# DLGDash

DLG / F3K 飞行仪表：大计时器、电压、发射高度、当前高度、四/六路舵量、历史曲线和升降提示音。

[从零安装](docs/INSTALL-BEGINNER.md) · [设置说明](scripts/edgetx/DLGDash/README.md) · [下载兼容测试版](https://github.com/SailTechnology/DLGDash/releases/tag/v1.0.1-beta.1) · [原 v1.0](https://github.com/SailTechnology/DLGDash/releases/tag/v1.0)

**Zorro 用户请下载 v1.0.1-beta.1 的 `DLGDash-v1.0.1-beta.1.zip`。此版包含旧固件兼容修复，仍需先在地面验证；原 v1.0 不包含这些修复。**

## 选择你的遥控器

| 遥控器 | 安装到哪里 | 当前状态 |
| --- | --- | --- |
| PA01 | 彩屏主屏，添加 DLGDash 控件 | 有前期实机反馈，更新后需复查 |
| HelloRadio V16 | 彩屏主屏，添加 DLGDash 控件 | 实验适配 |
| FrSky X9D / X9D Plus / Plus 2019 | 模型的 Display 页面，选择 Script → DLG | 实验适配 |
| RadioMaster GX12 | 模型的 Display 页面，选择 Script → DLG | 实验适配 |
| RadioMaster Zorro | 模型的 Display 页面，选择 Script → DLG | 新增旧版 EdgeTX 兼容测试 |

先在 SYS → VERSION 查看 **EdgeTX 版本**，不要把 ELRS 版本当作系统版本。Zorro 的 EdgeTX 2.7.1 已加入兼容测试，不要求为了试用先刷固件。OpenTX、Ethos 尚未验证。

## 安装顺序

1. 把遥控器内容盘完整备份到电脑。
2. 解压安装包，把 **SD 文件夹里面的内容**复制到遥控器内容盘根目录。
3. 安全弹出并重启，按上表添加显示页面。
4. 打开 DLG Setup，设置电压、高度、计时器、发射模式、舵机通道和按钮。
5. 保存，完成地面检查后再使用。

每一步的按键、文件位置和检查方法都在[新手教程](docs/INSTALL-BEGINNER.md)。

## 界面预览

以下为模拟数据画面。

![PA01 飞行仪表](docs/images/pa01.png)

![V16 飞行仪表](docs/images/v16.png)

![X9D 飞行总览](docs/images/x9d-large.png)

![GX12 飞行总览](docs/images/gx12-large.png)

![黑白屏六舵机页面](docs/images/gx12-servos-large.png)

![黑白屏中文设置](docs/images/gx12-settings-large.png)

## 使用前注意

- 安装不会改动混控、舵机方向、行程或射频参数。添加显示页面后，遥控器会保存该页面设置。
- 首次使用先选择自己模型的电压源、Zoom 模式和通道，不要照搬别人的绑定。
- 旧固件的提示音跟随遥控器总音量；舵量页标为 **MIX** 时表示混控量，不是最终舵机输出。
- 旧固件不能单独判断某个传感器是否过期；飞行前请核对原生遥测，接收机断电后仪表应显示失联并停音。
- 在控制链路可靠的前提下，**尽可能提高 ELRS 的有效遥测回传率**。不要在飞行中改包率；不了解相关参数时先保留原来的可靠设置。
- 仪表不代替原生低压告警、失控保护或飞行安全判断。
