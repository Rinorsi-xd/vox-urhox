# 坠舰陨坑正式画面对照（2026-10-06）

## 验收基准

最新原生截图标签为 `surface-depth`。本轮修复探照灯外壳穿透远处舰壁造成的短线，详见 `CRATER_SURFACE_DEPTH.md`；下文其他标签属于历史阶段。整体画面仍未完全一致。

源页为 `D:/Rino_Project/Vox/three/terrain-sample.html`，以只读 HTTP 服务打开原文件，使用 `?view=0/4/5&shot=1`。没有修改 H5 文件或玩家存档。三个机位分别是要塞、战舰外部和舰体内部。

`evidence/crater-source-overview.png` 是转换工具的画面，没有运行正式 `Pipeline` 后处理链；不能作为最终色彩验收基准。本轮正式参考是 `crater-source-formal-{fort,ship,interior}.png`。

浏览器与原生截图均为 2040×1080。原生按源页 eye/at 镜像 X，并用 `2*atan(18/lens/aspect)` 计算垂直 FOV。源页自动分辨率仍开启，三个截图的实际画布分别为 1836×972、1938×1026、1734×918；随机粒子与动画时刻未同步，不能进行逐像素相等判定。机位及边界写入 `evidence/crater-formal-reference.json`。

并排实际截图：`evidence/crater-formal-comparison.png`（左 H5，右当前 UrhoX）。这不是效果设计稿，也未用后期修图伪装一致。

## 修正

- `GraphicsSettings` 显式设置源 Pipeline 的 Bloom 阈值 1.3；保留源强度 0.18 和曝光 1.1。原生 UE Bloom 与 Three UnrealBloomPass 的算法不同，同参数不能当作完全等价。原生序列化确认 `Bloom UE Threshold=1.3`，渲染日志确认运行 UE Bloom。
- `CraterPreview` 使用游戏的 `GraphicsSettings`，消除原预览默认 Legacy Bloom 与游戏 UE Bloom 不一致的问题。场景 XML 和生成器也写入 UE Bloom 默认参数及暗角。
- 护盾在顶点阶段先归一化缩放后的法线，再插值，与源公式保持一致。旧程序 `Shield_D7F7B4F3` 已退役，该阶段程序为 `Shield_CBA61D6D`；现已被保留完整命中循环的 `Shield_EC44924C` 替代，见 `CRATER_SHIELD_EFFECTS.md`。
- 点光源不再把源强度除以 100。四盏舱内灯为 1400，两座要塞各为 160，范围 90 米、不开阴影。保持源暖白、己方冷白、敌方暖红三种颜色，显式关闭色温覆盖。引擎采用 `1/(d²+1)`，源页采用平方反比并带范围衰减，近距离响应仍非完全相同。
- 导出器在播放动画前记录静止姿态，并导出 `baseColor`。旧数据中 3 份材质颜色、36 个动态姿态已从原始六个 GLB/材料表恢复，避免喷口余火、反应堆和全息颜色重复衰减、核心上下浮动叠加偏移。检查涵盖 30 份发光颜色和全部 54 个动态节点，修改记录见 `evidence/crater-authoring-repair.json`。
- 旗帜旋转改为与源 Euler XYZ 相同的旋转顺序。`crater-animation-reference.cjs` 直接执行原 H5 的 `animateDyn`，以原 GLB 为初始状态，生成四个时刻的 54 个节点变换；原生逐个对照位置、旋转和缩放通过。
- 移除建筑 2.5–5 cm、光条 6 cm 的法线几何抬升，改为材质深度偏移。保留源三类偏移强弱关系，constant 用源 units/2²⁴、slope 用源 factor；当前 DX11 已核实实际加载和画面。舰内原先露出的宽橙色网格恢复为源画面的细线，储罐灯带与支架的遮挡关系也恢复。不同深度格式/后端的偏移仍须各自验证。

## 当前结果与剩余差异

主体几何、地形轮廓及机位对得上。舱内补光、动态初始姿态及地面光条遮挡已修正，但护盾/光条光晕、阴影柔和度、材质反射和整体空气感仍与原网页有差异。正式画面验收状态为 **未完全一致**。最新原生帧为 `crater-native-directlight-{fort,ship,interior}.png`；比较图可用 `compare-crater-parity.py --label directlight` 重建。

源链路是 HDR → shafts → HDR clamp → AO（陨坑关闭）→ bloom → mist → grade → ACES/output → lens。PC 自定义后处理现在覆盖该链，shafts 与 clamp 合并为一步。七组实际 H5 Pipeline 测试图最大通道误差 1/255，但画面输入本身的灯光/材质/阴影差异仍在。天空重复位移修复、同机位朝阳开关图及剩余天空输入差异见 `CRATER_SUN_SHAFTS.md`；该阶段正式机位标签为 `shafts`，当前为 `directlight`。旧 LUT 验证和编辑器回退记录保存在 `CRATER_COLOR_PIPELINE.md`。

后续继续核对天空输入和 PBR/阴影。最新实际 H5 后处理测试图与原生全像素比较最大误差 1/255；同步反应堆 .6/1 两端呼吸亮度的 `crater-breath-comparison.png` 表明旧舰内光晕差异主要来自未同步的动画相位。保持原 Bloom 参数，不据旧异步图削弱灯光。详见 `CRATER_POST_PROCESS.md`。地图流程最新为 58/58，以下为历史阶段验证计数。

## 验证

当前生命周期和连续冷缓存复测见 `RENDER_TARGET_LIFETIME.md`；以下为各阶段历史计数。

- `verify-crater-parity.ps1 -Label tonemap`：233/233，零 Lua/资源/引擎错误；包含 216 个源动态姿态对照、基础发光颜色与实际模型绑定、材质深度偏移、三个固定机位、灯光参数和 Zone 序列化。报告 `evidence/crater-parity.json`。它不判定 H5 视觉一致。
- `verify-crater-game.ps1`：35/35，选图、驾驶、相机输入回放、9 个区域、退出释放、原试车场入口通过。
- `verify-graphics.ps1`：45/45，PC 画质窗口与跨场景设置通过。色彩测试 `verify-color-pipeline.ps1`：185/185。
- 最新隔离开发缓存后，大厅探针 3/3、画质 45/45、陨坑 35/35 均通过，零新生成缓存文件。证据在 `evidence/pc-shader-cache-isolation.json`。本轮未重跑 FullMenus。没有操作编辑器，也没有把输入回放当作用户编辑器鼠标锁定的手动验收。

## 直射阴影与完整护盾接口

基地后方的暗壁已定位为烘焙直射阴影误乘底色，不是地形缺面。修复后崖壁纹理与环境光恢复，地形/远山/建筑统一分离直射阴影和间接 AO。源码、像素隔离检查及当前缓存结果见 `CRATER_DIRECT_LIGHT.md`。完整护盾 37 步源状态对照、九种实际画面和 50/50 结果见 `CRATER_SHIELD_EFFECTS.md`。这些修复不代表全部材质/阴影/天空逐像素一致。
