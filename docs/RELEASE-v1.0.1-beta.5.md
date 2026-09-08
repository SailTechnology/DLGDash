# DLGDash v1.0.1-beta.5：更多 EdgeTX 机型

仍然只下载一个包，不叠加安装：

- **Color**：PA01、HelloRadio V12 / V16、RadioMaster TX16S（一代 / 二代）/ TX15、Flysky PL18U、Jumper T15 / T16 / T18、FrSky X10 / X12S 系列。
- **Monochrome**：X9D 系列 / X9E、GX12、Zorro、HelloRadio V14、T14、Boxer、Pocket、TX12 / MKII、T12 / MAX、T20 / V2、T-Pro / V2 / S、T-Lite、X7、X9 Lite、X-Lite 系列。

新增机型均为实验适配。TX16S MK3、GX15、HelloRadio V12 MAX / V15、T15 Pro、EL18 等未列型号不在本轮范围。必须运行 EdgeTX，不能直接安装到 Ethos、FrOS 或 FlyskyOS。

## 更新内容

- 480×320 横屏使用大屏仪表和设置布局；保留 480×272、320×240 和两种黑白屏布局。
- 机型共用程序，不为每个型号加载一份代码；黑白屏不带彩屏资源。
- 电脑端安装检查扩展到机型表，并只安装对应屏幕资源。
- 保留黑白屏低内存设置、精简固件保存兼容，以及四 / 六舵机、曲线和音调设置。
- 添加完整机型表、分辨率说明和首次测试步骤。

T14 用户已反馈 beta.4 基本正常；本版新增机型通过离线模拟不代表完成实机验收。TX15 采用 2.12 接口模拟，厂商自编译固件还需地面复测。

## 升级步骤

1. 飞机断电。USB 存储模式下，把内容盘完整备份到电脑，尤其 MODELS、RADIO、WIDGETS/DLGDash/profiles。
2. 把旧 WIDGETS/DLGDash 改为未使用的备份名字，不覆盖已有备份。
3. 把 SCRIPTS/TOOLS/DLGSetup.luac、SCRIPTS/TELEMETRY/DLG.luac 改为未使用的备份名字；没有就跳过。
4. 下载对应 ZIP，解压，把 **SD 文件夹里面的内容**复制到内容盘根目录。不要下载 Source code 代替安装包。
5. 只将旧 profiles 复制回新插件目录，不带回旧脚本和编译缓存。不要改动 MODELS、RADIO。
6. 安全弹出并重启。进入设置，检查十页、修改保存、返回重进和重启读取。曲线积累后再试一次，并对照原生遥测。

黑白屏设置期间插件曲线和提示音暂停，请在地面操作。在控制链路可靠的前提下尽可能提高 ELRS 有效遥测回报率，不为刷新曲线牺牲链路稳定性。

[完整机型表](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.5/docs/RADIOS.md) · [彩屏保姆教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.5/docs/INSTALL-COLOR.md) · [黑白屏保姆教程](https://github.com/SailTechnology/DLGDash/blob/v1.0.1-beta.5/docs/INSTALL-MONO.md)

如有问题，请提供机型、SYS → VERSION 照片、包名、操作入口和完整错误照片，不公开模型备份。
