# 悬浮与推进驾驶（2026-10-06）

底挂/侧挂悬浮车以及六台 T5 重载车已在同一 TrialSession 接入原生物理、控制、关节显示和场景释放。源项目只读；测试蓝图来自原项目已有 `tools/fixtures/hover-car.js`、`thruster-heavy-car.js`，没有生成替代美术或新增另一套游戏入口。

## 使用

在项目根执行：

```powershell
./preview-hangar.ps1 -Trial -Blueprint HoverBottom -Quality mobile
./preview-hangar.ps1 -Trial -Blueprint HoverSide -Quality mobile
./preview-hangar.ps1 -Trial -Blueprint HeavyLift -Quality mobile
```

这些是三个可选启动命令，每次选一个。蓝图存放于 `assets/Blueprints`；只读取所选文件及车上实际使用的模型。默认启动仍为赤焰 GT。完整车位/建造 GUI 尚未接入，此参数用于迁移阶段直接体验源蓝图。

悬浮：W/S 前后、A/D 转向、Q/E 横移、Space/Shift 调高/调低离地目标。飞行：Space 起飞/爬升、松开后定高、Shift 下降/落地、X 断开升力；W 控制升力推进器向前倾转。固定侧推器是否能横移或偏航取决于实际安装方向，不能给没有对应推进器的车添加凭空转向力。六台 T5 蓝图保留赛车原有前推器，实际有六台升力推进器加一台固定前推器。

触控区按车辆能力提供升降、横移、断推；悬浮/飞行时不显示无效手刹按钮。释放、移出、取消和应用失焦清除保持状态。升降不自动触发武器。界面仍是迁移 HUD，尚未做最终手机布局和完整 GUI。

## 物理与原版差异

- 悬浮沿安装轴施力，使用向下地面射线和接触点相对竖直速度；35° 倾角失效、两倍额定高度之外无地面支撑、单台支撑上限为两倍额定载荷重力。高低目标保留源 0.6–1.35 范围。
- 飞行使用原版有界推进器分配，实际出力始终不超过额定推力；只通过施力/力矩驱动刚体。保留起飞、定高、前倾、下降、落地自动断推与手动断推。
- **原生质心适配**：侧挂悬浮车的 Bullet 复合刚体质心实测 z=0.45 m，平均分配支撑使车体持续俯仰并约以 0.9 m/s 前漂。`VehicleSetup.HoverShares` 现在根据测得的原生质心求总份额和水平力矩平衡，取相对额定份额的最小调整。若无非负解，保留额定份额；不会凭空补齐缺失一侧的支撑。悬浮力本身仍经过源公式和单台上限。
- 此支撑分配是对原生质量系统的适配，不是 Rapier 轨迹完全一致的证明。碰撞、质心和惯量仍有引擎差异；未实现逐形状原版质量分配。

## 显示与生命周期

`render/ActuatorView.lua` 只读取物理出力和方向，管理推进器万向架、转子加速/滑停和悬浮环旋转；模型仍共用 PartRig 层级。源零件旋转先还原到局部，再在 UrhoX 边界转换坐标，避免喷口双重倾转。

DriveView 在重建时重新绑定存活零件并保留其转角/转子速度；重置时清空旧输出，关节返回初始状态。ActuatorView 不创建独立模型/材质副本，退出试车时随所属车辆销毁。正常大厅启动不创建试车物理世界。

## 验证与证据

```powershell
./tools/migration/verify-air-drive.ps1
./tools/migration/verify-air-trial.ps1 -Blueprint HeavyLift -Quality mobile -Screenshot
./tools/migration/verify-air-trial.ps1 -Blueprint HoverSide -Quality mobile -Screenshot
./tools/migration/verify-air-trial.ps1 -Blueprint HoverBottom -Screenshot
```

- 控制和原生检查 **651 项通过**：540 组原版悬浮力、60 组推进器输出/方向/作用点/遥测对照，另含原生物理检查。
- 悬浮原生检查涵盖底挂和侧挂静止、升降、前进/释放减速、横移、转向；失去左侧支撑真实倾倒、越过平台边缘下落、倾角阈值。
- 飞行原生检查涵盖中立不点火、起飞定高、矢量前进、侧推偏航、断推下落、下降落地、推力不足不能起飞、状态恢复和复位。实际重载车质量 1871 kg；120 秒模拟巡航末速度约 82.08 km/h、末十秒速度变化小于 0.1 km/h，高度误差小于 0.2 m。此时长是模拟时间，不是真机持续负载时间。
- 同一应用入口的 HeavyLift 检查 **33 项通过**，包括实际关节世界方向、转子滑停、重绑保留状态、触控回调和返回释放；底挂/侧挂各 **28 项通过**。移动档在当前电脑运行，未操作桌面编辑器。
- 地面原生驾驶 22 项、移动档机库/试车往返 34 项、靶车破坏 7918 项回归通过。详细报告位于 `evidence/air-drive.json`、`air-drive-measurements.json`、`air-trial-*.json`。
- `evidence/air-drive-states.png` 对照停机、定高前倾、断推、底挂与侧挂；这些是分别回放的状态截图，不是连续视频。

## 待完成

推进器体积尾焰/余焰、悬浮体积光场/地面光斑及动态发光已接入，见 EQUIPMENT_EFFECTS.md。悬浮发射点射线目前仍按物理频率计算，特效直接读取结果，不另增射线；后续需结合真机预算评估分频。

节足移动已接通，验收范围见 LEG_MIGRATION.md。完整 GUI、编辑器原生崩溃定位、远端按需下载、骁龙 845 真机持续帧率/温度仍未完成；不得以本机 mobile 档检查代替这些验收。
