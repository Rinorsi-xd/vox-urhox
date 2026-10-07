# PC 当前交付与剩余工作（2026-10-07）

活动工程：`D:/Rino_Project/maker/Vox/VoxelCraft`。H5 源 `D:/Rino_Project/Vox` 只读。本次收尾完成当前驾驶相机和已迁移基线的流程验证；不代表全量迁移完成。

## 启动与编辑

工程根目录运行 `./preview-hangar.ps1 -Quality desktop`。大厅 → **出战** → **[debug]坠舰陨坑地图测试** → **开始战斗**。点击画面接管鼠标，移动鼠标控制视角，滚轮调整距离；Esc 释放鼠标，释放后右键拖动观察，再次 Esc 或 T 返回车库。W/S 油门与刹车，A/D 转向。

编辑器通过“文件 → 打开场景”选择 `assets/Scenes/OrbitalHangar.xml`（大厅）、`assets/Scenes/Crater.xml`（陨坑）或 `assets/Scenes/TrialTrack.xml`（试车场）。完整玩家流程由 `scripts/main.lua` 启动，编辑环境场景与运行游戏的入口不同。此前编辑器未响应的根因仍未确认。

## 载具视角修正

- 默认俯视角由 14° 提高至 30°，默认距离至少 24 m，并按车辆包围半径扩大。轮式/履带车辆观察目标抬至至少 3.8 m，节足车辆跟随实际车体中心。
- 继续使用 ThirdPersonCamera 库，支持鼠标环绕、滚轮缩放和跟车模式。
- 出生点旧镜头落进后墙外凸的蓝色标牌；相机避障余量由 0.2 m 增至 0.85 m。没有修改标牌材质或抬升显示几何来遮掩问题。
- 新增 `scripts/controls/CameraObstacles.lua`，为不透明静态建筑表面创建相机专用三角碰撞代理，补齐粗略驾驶碰撞体没有覆盖的屋顶和装饰。代理为 trigger，玩法射线忽略它们，不阻挡车辆或武器。
- 顶棚缩短相机距离时自动扩大视野，最高 76°，保留完整车身；开镜不受该补偿影响。侧面视角仍可能被实际建筑柱子遮挡，未承诺任意角度完全无遮挡。

以下为实际原生 Runtime 截图，已检查车顶、完整车身和前方可见区域：

![室外驾驶视角](evidence/crater-native-outdoors.png)

![出生点驾驶视角](evidence/crater-default-orbit-0.png)

大型节足截图：[LegT5](evidence/current-leg-LegT5-desktop-walk1.png)。武器截图：[试车场射击](evidence/current-combat-desktop.png)；该测试主动调整了镜头，不作为默认相机机位证据。

## 本次验证

| 检查 | 结果 | 证据 |
|---|---|---|
| 陨坑进入、默认机位、四向观察、输入/缩放、驾驶、九区传送、返回和释放 | 67/67 | [crater-game.json](evidence/crater-game.json) |
| 24 种面板建造、保存、重载、进图及返回 | 1887/1887 | [panel-session.json](evidence/panel-session.json) |
| PC 武器射击、命中与遮挡 | 94/94 | [combat-desktop.json](evidence/combat-desktop.json) |
| 大型 LegT5 PC 行走及完整车身画面 | 16/16 | [leg-trial-LegT5-desktop-walk1.json](evidence/leg-trial-LegT5-desktop-walk1.json) |
| 隔离本机 DX11 缓存，大厅 + 陨坑 + LegT5 | 通过；零新编译文件 | [pc-shader-cache-isolation.json](evidence/pc-shader-cache-isolation.json) |

以上运行报告均无 Lua、资源或引擎错误。当前项目 shader 包为 557 文件、4,314,106 字节，指纹检查通过；隔离测试结束已恢复原开发缓存。

冷缓存探针最大帧 291.03 ms，陨坑 401.68 ms。LegT5 测试在单次回调内同步模拟大量步进，最大帧 3621.21 ms，不能当成正常驾驶帧率；这些测试都不证明持续 60 FPS。该测试第一次曾超过 110 秒，原始日志保留于 `evidence/leg-t5-closeout-timeout-out.txt` / `leg-t5-closeout-timeout-err.txt`；后续普通与冷缓存重跑通过，但首次超时根因未确认。本轮冷缓存组合未重跑 FullMenus、Graphics 或 Parts。

复现冷缓存组合：

```powershell
./tools/migration/verify-pc-shader-cache.ps1 -Python <Python路径> -Crater -Legs
```

## 尚未完成的迁移

1. 当前原生基线 198 类零件，源已更新至 201 类。三个转轴 `rotor` / `rotorSpin` / `rotorStep`、组合分组/拆分、拉伸及对应序列化和快捷键尚未同步。
2. 大厅、地图、GUI、透明材质、光照与特效仍需逐项对齐源画面，不能称为一模一样。
3. 已有按地图加载、分帧准备和离开释放；真实远端边玩边下、弱网恢复、按地理区域下载与通用有状态 Lua 热更新未完成。
4. 编辑器崩溃根因和长时间性能验收尚未完成。当前只交付 PC 横屏工作，移动端适配暂停。

源资产一致性检查仍因源哈希更新而 FAIL，部件检查为 2869/2870（源与目标数量不同）；没有降低测试标准。详见 [源同步差异](CURRENT_SOURCE_DRIFT.md)。下一批应先补齐源转轴/组合/拉伸行为及存档兼容，再做视觉逐项对照，最后验证远端下载和长期性能。
