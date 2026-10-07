# VoxelCraft · UrhoX

H5 源工程 `D:/Rino_Project/Vox` → 当前 UrhoX 工程。源目录只读。当前优先完成 PC 横屏（16:9 和 PC 窗口比例），界面以原网页为依据使用 NanoVG；移动端与竖屏适配暂停。

当前迁移基线为 198 类零件；源后续新增至 201 类，完整迁移尚未完成。最新完成项、实测截图和剩余边界见 [PC 收尾记录](docs/migration/PC_HANDOFF.md) 与 [源同步差异](docs/migration/CURRENT_SOURCE_DRIFT.md)。

## 运行游戏

在本工程根目录运行：

```powershell
./preview-hangar.ps1 -Quality desktop
```

大厅 → **出战** → **[debug]坠舰陨坑地图测试** → **开始战斗**。大厅的试车按钮或 T 进入原试车场。

局内操作：点击画面接管鼠标，移动鼠标转视角；滚轮调远近。W/S 油门与刹车，A/D 转向，C 切换镜头跟车，R 翻正，N 切换地图区域。Esc 释放鼠标，释放后右键拖动仍能观察；再次 Esc 或 T 返回车库。

默认镜头采用较高的 30° 俯视跟车、至少 24 m 距离（按车体尺寸扩大）。室内自动避让墙体和顶棚，并扩大视野保持车身完整。实际截图见 [出生点](docs/migration/evidence/crater-default-orbit-0.png)、[室外](docs/migration/evidence/crater-native-outdoors.png)。

## 编辑器中的场景

在 UrhoXEditor 打开本工程，通过 **文件 → 打开场景** 选择：

- `assets/Scenes/OrbitalHangar.xml`：大厅环境、灯光、材质及动态物件的锚点。
- `assets/Scenes/Crater.xml`：坠舰陨坑完整地图。
- `assets/Scenes/TrialTrack.xml`：试车场。

Scene 模式用于编辑已保存场景；车辆、动态效果和完整玩家流程由 `scripts/main.lua` 启动。嵌入式大厅预览与独立运行的验收边界见 [建造迁移](docs/migration/BUILD_MIGRATION.md)。编辑器此前未响应的根因尚未确认，独立 Runtime 测试通过不能代表编辑器稳定性已解决。

## 建造与存档

大厅选择 **改装战车 · E**。支持镜像放置、旋转/倾斜、选择与移动、涂装、复制粘贴、撤销重做、20 车位及 H5 蓝图码。建造结果直接进入试车，返回仍保留同一份蓝图。

B 零件库，G 材质，R 旋转，M 镜像，P 涂装，X 拆除，V 透视，Ctrl+S 保存。完整键位与当前源差异见 [建造迁移](docs/migration/BUILD_MIGRATION.md)；组合块、拉伸和新转轴尚未同步，不能把这些功能当成已支持。

已导入 198 类、203 份 rig、359 个共享模型和 198 张原版透明图标。赤焰 GT 为 209 件，磐石为 223 件。新增的 24 种面板已验证实际放置、保存、重载和进图往返。

## 工程结构

- `scripts/app/`：单一应用入口、大厅/建造/驾驶会话与生命周期。
- `scripts/construction/`、`drive/`、`combat/`：蓝图、车辆和战斗规则；避免 Maker 打包器保留的 `build` 目录名。
- `scripts/controls/`、`render/`、`ui/`：输入/相机、场景表现、原版 PC 界面。
- `assets/Scenes/`、`Parts/`、`Crater/`、`Shaders/`：编辑器可见场景及运行资源。
- `tools/migration/`：源数据转换和验收工具；`docs/migration/evidence/` 为验收证据，不随游戏资源打包。
- `urhox-libs/`：引擎参考库，只读。

详细所有权、加载及热重载约定见 [架构文档](docs/ARCHITECTURE.md)。按所选地图加载、分帧准备和退出释放已经实现；真实远端边玩边下及完整 Lua 状态热更新仍未完成。

## 验证

依次执行，不并行运行多个 GPU 实例：

```powershell
./tools/migration/verify-crater-game.ps1
./tools/migration/verify-panel-session.ps1
./tools/migration/verify-combat.ps1 -Quality desktop -Screenshot
./tools/migration/verify-leg-trial.ps1 -Blueprint LegT5 -Quality desktop -Screenshot
```

这些检查使用独立测试实例/测试存档，不替代实际画面检查或用户验收。最新源一致性检查 `node tools/migration/verify-source-assets.mjs` 当前因源后续更新而失败，详见源同步差异；不可通过降低期望值将其改成成功。
