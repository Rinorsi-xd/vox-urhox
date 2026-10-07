# 武器机械动作与持续特效（2026-10-06）

同一个 VehicleView 现在用于机库车辆、分页目录、试车玩家和靶车。12 种原版武器的机械动作、发光、能量流及 T4/T5 常驻特效已接入；显示层不回写瞄准、能量、射线或伤害。

## 实现与归属

- `render/WeaponMotion.lua`：原版弹簧后坐/抬枪、枪管震动、鼓轮、线圈、散热片、炮冠、导轨、磁环、陀螺、能量匣与停机/上线状态。全部在原版格坐标中计算。
- `render/WeaponPresentation.lua`：将动作转换为 UrhoX 关节变换，每把武器按动态材质槽各持有一份材质；模型仍然共享。移除武器立即 Dispose 私有材质。
- `Weapon.shader`：枪身轴向流光、底座环形流光、停机余光与上线扫光。顶点参数使用原始模型原点，不能加车辆内的安装位置；动作不会重新计算模型上的流光坐标。
- `render/WeaponEffects.lua`：VehicleView 持有，最多四个惰性批次（光点、能量环、漩涡、无噪声电弧）。批次位于场景根，最终炮塔姿态应用后转为世界米坐标，避免 CELL 缩放两次。特效读取相机和实际武器状态，不增加物理射线。
- 加特林 T4/T5 满转枪口漩涡、T5 火花；激光 T4/T5 滑动能量环与绕管粒子；狙击蓄力球、T4/T5 吸入粒子/轨道电弧、T5 轴向电磁通道。停机电花、上线闪光通过既有 CombatEffects 的有限池发出。
- 复位清空视觉弹簧和持续特效瞬态，保留实际能量、冷却与射击基线。破坏后重绑保留存活武器状态；移除最后一把武器立即释放批次；退出车辆释放全部私有显示资源。

直接移植源 `three/src/parts/weaponRig.js`、`weaponFlow.js`、`fx/ribbons.js` 的公式，没有生成新的美术资产。源 Canvas 发光圆以等价的三段径向梯度 Shader 表达，存在纹理采样/光栅化差异，不宣称逐像素等同 Three。

## 移动端约束

| 每车上限 | mobile | desktop |
|---|---:|---:|
| 更新持续特效的最近武器 | 12 | 24 |
| 光点批次 | 192 | 768 |
| 电弧光条段 | 640 | 2048 |
| 单武器存活电弧 | 8 | 16 |
| 漩涡圆周段 | 20 | 40 |
| T4/T5 绕管或吸入粒子 | 16 / 24 | 36 / 56 |
| 粒子详细距离 | 25 m | 55 m |
| 特效截止距离 | 70 m | 140 m |

环最多 64 片/车；漩涡批次最多 16 个满细节圆周。超过预算只舍弃视觉，不影响武器计算。远处删除持续特效状态，不积攒电弧；返回近处重新建立。帧间隔最多消费 0.1 秒，每次最多四次电弧生成调度。修正源实现停机计时一直变负、重启可能集中补发的问题，不重放停机期间的电弧。

仍有 Lua 临时向量、几何上传和首次 Shader 编译成本。这是桌面 Runtime 的 mobile 配置验证，**不是骁龙 845 的持续帧率、温度或功耗验收**。多车总开销仍需真机 profiling。

## 验证与画面

```powershell
./tools/migration/verify-weapon-motion.ps1
./tools/migration/verify-weapon-effects.ps1 -Screenshot
./tools/migration/verify-weapon-effects.ps1 -Kind mg -Quality mobile -Screenshot
./tools/migration/verify-weapon-effects.ps1 -Kind sniper -Quality mobile -Screenshot
./tools/migration/verify-weapon-effects.ps1 -Quality mobile -Phase offline -Screenshot
./tools/migration/verify-weapon-effects.ps1 -Quality mobile -Phase boot -Screenshot
./tools/migration/verify-weapon-effects.ps1 -Quality mobile -FlowCheck
```

- 从实际 Three WeaponRig 生成 12 类 × 260 步机械/材质样本，原生比较关节矩阵、弹簧、事件和材质参数；含安装位置不污染底座流光及材质释放检查，共 3156 项通过。
- 从实际 Three WeaponRig 生成 6 类 × 120 步持续特效样本；比较旋转/后坐后的能量环位置/半径/亮度、粒子位置/尺寸/亮度和电弧状态。随机数固定为 0.5 以定位公式误差；实际截图使用独立视觉随机序列。桌面验证还覆盖 60 秒停机恢复、预算、距离释放、重置与销毁。
- GPU 像素对照：在车辆内平移安装位置并补偿车辆根位置，画面完全相同（采样区最大差 0）；只改变流光相位，有 11,585 个像素变化大于 20。见 `evidence/weapon-flow-pixels.json`。此项确认 Shader 真正工作，不只检查 uniform 数值。
- 受控画面见 [weapon-states.png](evidence/weapon-states.png)：激光、加特林、狙击、停机、上线以及同一试车应用的实际射击。截图是冻结状态，不是手机或编辑器交互验收。
- 同轮回归：原版武器逻辑 2223 项、炮口适配 49 项、mobile 实际战斗 92 项、破坏 7918 项、目录/视角/按键/GC 压力 92 项全部通过，零 Lua/资源/引擎错误。

DirectX 的 SurfaceShader 转译曾在能量环的复合 discard 分支触发 HLSL 编译器内部错误；改为等价区间掩码和单次 discard 后已通过真实渲染。没有修改生成的底层 Shader。

## 后续边界

T5 弹道二次电弧与瞬时点光现已接入并完成源公式/实际渲染验证，见 [COMBAT_PRESENTATION.md](COMBAT_PRESENTATION.md)。装备表面微纹理、部分闪光、声音和镜头震动仍需核对。完整建造和 GUI 的后续进展应以各自最新文档为准，不能沿用本页早期“下一阶段”的状态判断。远程弱网边玩边下、845 真机性能、编辑器崩溃根因均未验收，整个迁移目标仍未完成。
