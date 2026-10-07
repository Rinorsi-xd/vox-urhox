# 装备特效迁移

源工程只读：`three/src/parts/thrusterFx.js`、`hoverFx.js`、`legRig.js`、`three/src/drive/legContactView.js`。复用原 Mivo 能量流纹理，没有重新生成美术或添加浏览器运行依赖。

## 当前接入

- 推进器：真实出力控制点火/熄灭，原版体积密度、蓝白焰芯、波节、喷口光晕；尾焰附着万向架下的 housing，不重复倾转。余焰保留世界位置和喷口速度，断推后消失，重置立即清空。
- 悬浮：读取物理 `emitHits`，从发射口连接真实地面点；法线对齐光斑，无接触时关闭。特效不另发射线。发射点射线仍按物理频率计算，尚未分频。
- 节足：仅真实着地脚产生接触环，新增着地有 0.16 秒脉冲；跳跃发光读取 `jumpGlow`。原版此处是接触环，不是额外落脚粒子或点光源。
- 发光强度通过实例数据传给共享材质，避免每个零件复制材质。大厅显示建模初始值，试车读取动态状态。

## 结构和预算

`EquipmentState` 保存纯公式；`EquipmentEffects` 随 DriveView 管理装备和批次；`EquipmentResources` 跨车辆引用计数，最后一个使用者释放体积材质和纹理引用。资源在进入带相应装备的试车时才引用，远端异步就绪时间尚未验收。

每个喷口/悬浮发射点一个共享立方体代理，光晕、光斑、接触环、余焰按车辆聚合为至多四个动态批次。存活零件重绑保留出力与脉冲，移除零件立即销毁代理。退出试车清空批次、粒子和引用。

| 预算 | mobile | desktop |
|---|---:|---:|
| 近距尾焰采样 | 12 | 32 |
| 近距悬浮采样 | 8 | 12 |
| 减半采样距离 | 25 m | 55 m |
| 关闭体积/接触效果距离 | 70 m | 140 m |
| 每车余焰上限 | 96 | 384 |
| 每推进器余焰上限 | 48 | 48 |

光斑/光晕/接触环各批上限 256；预算目前按车而非全场分配，大规模多人仍需场景总预算。距离裁剪不改物理。移动档不等于骁龙 845 实机已达标。流纹理 1,804,596 字节，SHA256 `b8baddd21047142114645b448beb904c6ba8ccdaff9d68252e0ed4bebd2767e9`。

体积使用 SurfaceShader 背面代理，覆盖相机在内/外的情况，积分与不透明深度裁剪。Windows HLSL 编译器对双面分支报内部错误，改为与源一致的背面代理；循环使用显式纹理 LOD 0。使用引擎反投影，不自行套用 Godot reverse-Z。

**遮挡契约**：遮挡物必须写入场景深度。旧 `NoTextureUnlit` 没有 depth pass，在桌面前向的预深度纹理中不可见；项目实际场景材质使用有 depth pass 的 SurfaceShader。半透明玻璃不视为不透明挡板。

## 验证

```powershell
node tools/migration/source-equipment-fixtures.mjs
./tools/migration/verify-equipment.ps1 -Blueprint HeavyLift -Screenshot
./tools/migration/verify-equipment.ps1 -Blueprint HoverBottom -Screenshot
./tools/migration/verify-equipment.ps1 -Blueprint HoverSide -Screenshot
./tools/migration/verify-equipment.ps1 -Blueprint LegT5 -Screenshot
./tools/migration/verify-equipment-depth.ps1 -Kind Thruster -Phase on
# 两种 Kind × on / off / inside，随后执行 equipment-evidence.py
```

直接执行原版 11 份 ThrusterRig、1430 次状态更新，比较出力、材质强度、长度、半径、闪烁。真实试车 HeavyLift 1478 项（mobile/desktop）、两种悬浮各 1458 项、T5 腿 1448 项通过，含源对照与喷口轴/米制尺寸、地面端点、断推余焰、失去接触、远距隐藏、重绑、重置、移除装备、回机库释放。

深度专项两种材质各三张截图：无遮挡、全遮挡、局部遮挡、相机在体积内部。on/off 像素差中完全遮挡区最大差为尾焰 0、悬浮 1（8 位色），无遮挡区明显变化；相机内部仍有有效光场。见 `evidence/equipment-depth-pixels.json`。`evidence/equipment-states.png` 是六个受控状态的独立截图拼图，不是录像。

本轮回归：地面驾驶 22、飞行 651、节足 142、移动试车 34、战斗 92、破坏 7918，共 8859 项通过，无 Lua/资源/引擎错误。

未完成完整武器装备特效细节、音效/震动、完整 GUI、远端边玩边下与弱网验收、骁龙 845 持续性能验收。编辑器原生崩溃根因未确认，本轮未操作用户编辑器。
