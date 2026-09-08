# 彩屏安装与更新

适用 PA01、HelloRadio V16、HelloRadio V12，使用 EdgeTX。V12 的滚轮操作另见包内 [V12 教程](INSTALL-V12.md)。本版仍需实机地面验收，不要求先刷 EdgeTX 或 ELRS。

## 1. 下载并备份

1. 在 [beta.4 发布页](https://github.com/SailTechnology/DLGDash/releases/tag/v1.0.1-beta.4)的 Assets 下载 **DLGDash-Color-v1.0.1-beta.4.zip**，不要选 Monochrome 或 Source code。
2. 飞机断电，遥控器开机，拍下 SYS → VERSION 页。确认是 EdgeTX，不把 ELRS 版本当成系统版本。
3. 用数据线接电脑，选 USB Storage / USB 存储。在电脑找到含 MODELS、RADIO、SCRIPTS 的内容盘，不向固件升级盘写入。
4. 将内容盘完整复制到电脑一个带日期的新目录，检查模型及 WIDGETS/DLGDash/profiles 已备份。

## 2. 升级旧版

第一次安装直接到第 3 节。

1. 完整备份后，将内容盘 `WIDGETS/DLGDash` 改名为未使用的名字，如 `DLGDash-before-beta4`。
2. 将 `SCRIPTS/TOOLS/DLGSetup.luac` 改为未使用的备份名字；没有则跳过。不要改其他插件，不删除 MODELS 或 RADIO。
3. `.luac` 是旧编译缓存，复制新 `.lua` 后若保留旧缓存，可能仍运行旧版。不要把整个旧插件目录复制回来。

## 3. 复制新文件

1. 解压 ZIP，将 **SD 文件夹里面的内容**复制到内容盘根目录，允许合并和替换插件入口，不要多套一层 SD。
2. 升级用户只将旧插件目录的 **profiles** 复制回新 `WIDGETS/DLGDash`。
3. 检查以下路径：

```text
WIDGETS/DLGDash/main.lua
WIDGETS/DLGDash/draw.lua
WIDGETS/DLGDash/settings.lua
WIDGETS/DLGDash/color-settings.lua
WIDGETS/DLGDash/pages/1.lua         pages 中应有 1.lua 至 10.lua
WIDGETS/DLGDash/lang/zh.lua
WIDGETS/DLGDash/lang/zh/
WIDGETS/DLGDash/profiles/
WIDGETS/DLGDash/diagnostics/
SCRIPTS/TOOLS/DLGSetup.lua
```

空目录漏解压时手动新建 profiles、diagnostics。不要覆盖 MODELS、RADIO，也不用改混控、输出、射频。

4. 等待复制完成，安全弹出、拔线并重启。已添加的 DLGDash 页面不用重建。

## 4. 添加主屏仪表

1. 选中目标模型，打开 **Screen Settings / 屏幕设置**。
2. 选一个空白主屏页，将 Layout / 布局设为 **1×1**。
3. 进入 Setup Widgets / 设置控件，选中大区域，在列表选择 **DLGDash**。
4. 弹出的 ToneSw、SwHigh、ToneMin、Timer 可先保持默认，稍后在 DLG Setup 设置。
5. 关闭该页面多余顶部栏、飞行模式栏、滑杆和微调显示，腾出空间。**不用 App Mode**，不关闭真正的微调或控制功能。

![PA01 仪表，模拟数据](images/pa01.png)

![V16 仪表，模拟数据](images/v16.png)

## 5. 打开设置并保存

推荐从 **SYS → TOOLS → DLG Setup** 打开。仪表入口则先通过控件菜单选择 **Full screen / 全屏**，再按确认键或点 SET。普通 1×1 铺满画面不等于全屏，不能直接接收插件设置按键。V12 只用滚轮和按键。

滚轮移动高亮，确认键打开和确认选项，返回键取消列表。底部 `<`、`>` 翻页，Save 保存，Exit 退出。有星号表示未保存，连续两次退出丢弃修改。看到 Saved / 已保存后退出并重进确认。

| 页码 | 需要填写 |
| --- | --- |
| 1 | 实际电压源通常 RxBt，不选 RxBt+ / RxBt-；核对 1S/2S、普通/HV |
| 2 | 高度、垂直速度、原生计时器、曲线平滑 |
| 3 | 从哪个模式退出后结算发射高度，延迟时间，取结束值或峰值 |
| 4、5 | 四/六舵机及各输出映射，仅影响显示，不改混控 |
| 6 | 曲线时间窗、采样周期、清除按钮和生效位置 |
| 7、8 | 提示音开关、位置、按住/切换、死区、音调、节奏、音量 |
| 9 | English / Chinese，选择后保存 |
| 10 | 对照当前电压源和 RxBt，插件不自动修正接收机误差 |

## 6. 地面验收

分别通过 SYS 和仪表全屏进入，打开选源列表、滚动、确认并保存；停留至少两分钟，再退出和重进。重启后检查设置保留，切模型检查没有串用。核对电压、高度、计时器、各舵面映射、清曲线按钮与声音开关。

在链路稳定且满足实际使用需求的前提下，尽可能提高 **ELRS 遥测回报率**；不要只提高控制包速率或为了刷新牺牲链路稳定性。

V16 若仍报 `number expected, got function`，确认不是 beta.2，并检查旧缓存是否隔离。不要忽略报错飞行；拍下完整错误、VERSION 页、安装包名及触发步骤，不公开模型备份。

若需要回收存储，确认电脑备份及新版运行正常后，将改名的旧插件目录移回电脑。教程和 images 可只保留在电脑阅读；`WIDGETS/DLGDash/lang` 是运行资源，不能删除。
