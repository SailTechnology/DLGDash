# DLGDash v1.1.1-test.1：发射高度缺测恢复

本测试版修复高度回传断续时，整次发射一直显示 `NO FIX` 的问题。有有效峰值就保留，完全没有高度时等待回传恢复。曲线平滑和模型绑定保持原有设置。

## 下载

在下方 **Assets** 下载与遥控器屏幕相符的 ZIP：

- 彩屏：`DLGDash-Color-v1.1.1-test.1.zip`，适用 PA01、V12、V15、V16、TX16S 等已列机型。
- 黑白屏：`DLGDash-Monochrome-v1.1.1-test.1.zip`，适用 T14、Zorro、GX12、X9D 等已列机型。

只安装一种包，不要下载 Source code 代替安装包。机型范围与 v1.1 相同，详见[机型表](https://github.com/SailTechnology/DLGDash/blob/v1.1.1-test.1/docs/RADIOS.md)。包内 `README.md` 是对应屏幕的安装教程，`UPDATE.md` 是本页说明。

## 怎样记录 Zoom 及退出后的最高值

进入 **DLG Setup → 第 3 页“发射 / LAUNCH”**：

1. **退出此模式 / Exit this mode**：选择自己模型的 Zoom，不照抄别人的 FM 编号。
2. **退出后延迟 / Delay after exit**：例如设为 2.0 秒，可在 0～10 秒之间调整。
3. **高度结果 / Height result**：选 **阶段峰值 / Peak: mode + delay**。
4. 选择 **保存 / Save**。

从进入 Zoom 开始，到退出 Zoom 后两秒结束，取整个区间内收到的最高高度。例如 Zoom 内最高 50 米，退出后升到 56 米、结束时降到 53 米，最终显示 56 米。延迟设为 0 秒时，退出 Zoom 就结算。

“延迟结束值 / At end of delay”只取结算时的高度，用于希望记录指定时刻高度的用户。

## 回传断续时怎么看

| 显示 | 含义 |
| --- | --- |
| `52.7` | 选定方式的发射高度结果，单位米 |
| `~52.7` | 存在缺测或脚本暂停，保留已收到的数据；阶段峰值可能低于实际最高点 |
| `WAIT / 等待` | 尚无可用结果，继续等待高度回传 |
| `>52.7` | 等待后收到的首个有效高度，是延后读数，不能作为准确的发射峰值；`>` 不是大小比较 |

阶段峰值在窗口内收到过高度，就保留其中最高值，之后恢复的更高数据不会改写已结算峰值。整个窗口都没有高度时，才等待首个有效读数。选择“延迟结束值”时，如果结算时无数据，也会进入等待。

等待没有超时限制；收到结果后固定显示，下一次进入所选发射模式重新记录。断续回传期间，曲线平滑不会编造缺失高度，也不参与发射峰值计算。

## 升级步骤

1. 飞机断电，将遥控器以 USB 存储方式连接电脑。
2. 先把整个内容盘备份到电脑，特别保留 `MODELS`、`RADIO` 和 `WIDGETS/DLGDash/profiles`。
3. 解压对应 ZIP，将 **SD 文件夹里面的内容**复制到遥控器内容盘根目录，合并文件夹并覆盖插件文件。不要额外套一层 SD 目录，不要删除自己的 profiles。
4. 清理本插件的旧 `.luac` 编译缓存：`WIDGETS/DLGDash` 目录内的 `.luac`、`SCRIPTS/TOOLS/DLGSetup.luac`，以及黑白屏的 `SCRIPTS/TELEMETRY/DLG.luac`。没有则跳过，不删 `.lua` 源码和其他插件文件。
5. 安全弹出、拔线并重启。按上文设置 Zoom、延迟及阶段峰值，保存后重新进入确认。
6. 在地面检查：正常回传时能结算；短暂中断后保留已有峰值；完全无高度时显示等待，恢复后显示带 `>` 的读数；下一次发射重新记录。

不需要为了本次升级刷 EdgeTX 或 ELRS 固件。本插件不修改混控、舵机方向、行程或射频参数。黑白屏进入设置会暂停插件的记录和提示音，请在地面操作。

[彩屏详细安装教程](https://github.com/SailTechnology/DLGDash/blob/v1.1.1-test.1/docs/INSTALL-COLOR.md) · [黑白屏详细安装教程](https://github.com/SailTechnology/DLGDash/blob/v1.1.1-test.1/docs/INSTALL-MONO.md) · [全部设置说明](https://github.com/SailTechnology/DLGDash/blob/v1.1.1-test.1/scripts/edgetx/DLGDash/README.md)

## 验证范围

本次已通过缺测恢复、等待、零高度、下一次发射重置及脚本暂停的离线回归；彩屏和黑白屏界面、旧固件及受限内存检查通过。修复已安装到一台 PA01 并完成文件校验，真机使用效果仍待反馈。发布为测试版，不代表全部机型已经实测。

在控制链路可靠的前提下，尽可能提高 **ELRS 有效遥测回报率**。平滑只能改善已有数据的显示，不能补回未收到的真实高度。
