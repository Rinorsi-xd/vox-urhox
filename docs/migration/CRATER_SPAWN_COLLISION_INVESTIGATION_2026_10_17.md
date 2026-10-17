# 陨坑出生点与坡道碰撞调查

日期：2026-10-17。生产分支 `1016`，HEAD `f94827b26fc12b707e6d6904d093e16358caaf41`，含其他并行会话未提交修改。初始调查只读；后续已修改陨坑碰撞入口，车辆参数未改。

## 当前结论

后续已在真实 Native 物理中复现，确认一类根因为**漏迁移 H5 的运行入口碰撞过滤**。以下旧调查保留过程证据；“未复现”仅适用于当时的中心路线，不能覆盖新增接触证据。

冻结 H5 `b2760649` 的 `three/src/drive/testDrive.js:489–498` 在地图创建后会移除旧 `rock/spire/detail(module=rocks)` 及 `GHOST_BLOCKS`，然后用可见 rocks/debris 三角网格建立碰撞。导出器只保存 `buildCraterWorld().layout`；UrhoX 未执行后续入口处理，故启用了 H5 已弃用的碰撞。原版注释也明确记录凸包封闭岩脚凹槽、形成最高约2m的不可见台阶。

当前生产修复保留原1910条布局与Hull索引，仅跳过源规则选中的1613条（其中部分原已noPhysics），保留297条/288条有效结构碰撞。新增10个现有可见模型的147264三角碰撞，无模型减面、无改动驾驶/地形/EnginePit参数；描述资源 `Crater/DrivingCollision.json` 为13383字节。加载过程逐模型checkpoint，单个模型BVH构建仍须实测。

独立离线检查通过真实H5过滤集合、模型字节/顶点/绕序/世界变换/材质、Hull159和边界保留；11项负控包含顶点和绕序实改，全部被拒绝。证据 `evidence/crater-driving-collision-independent-2026-10-17.json`。这不替代真实接触或性能验收。

真实 Native 赤焰GT（209零件、4轮）复现：源起点 `(-57,-202)` 沿+Z，旧碰撞行驶7.927m后持续接触Hull190，4轮有支撑、发动机持续施力；仅禁该组旧方盒后77.974m；应用完整H5网格方案后89.009m且该段无岩接触。这证明实际阻车，非射线推测。另mesa源x11.2路线停在Hull838，完整网格替换后仍会撞到真实DrivingSurface_314，不能把朝向可见岩石的路线计作空气墙已消除。截图无坐标，尚不能断言用户该张图的精确位置已逐像素复现。

新冻结 `.tmp/outgame-cached-1792180474126` / `manifest-b88e4703.json`，547 Lua，指纹 `ec5935b3f3c68879026f76b799c112dd9289fd21d146a76cf975bc327889aa22`。普通4514与QA4515实际HTTP identity/manifest/main字节核验通过；4504仍保留旧3aca包，不热换用户场景。新Web运行与生产构建Native实测接续记录见下方。

后续完整生产Native构建通过：479个物理root子节点、10个DrivingSurface、147264三角。mesa源x29/z-177同起点10m短窗，旧版8.737m停住，新版10.028m通过；三个原本可过的负控仍可过。EnginePit未生成DrivingSurface（headless仅补两个甲板视觉node句柄，不签完整关卡画面）。单次Native构建838ms，其中网格构建271ms；这是边界数据，非性能提升结论。详 [Native接触报告](CRATER_AIRWALL_NATIVE_CONTACTS_2026_10_17.md) 与归档 `evidence/crater-airwall-contacts-2026-10-17/`。

Web同包 `evidence/debug-settings-1792180792333/` 为PASS/CLOSED：实际载入新碰撞日志、出生点持W20秒、暂停鼠标标记落盘，运行/HTTP错误0。root实看驾驶截图，出生坡道与场景/HUD正常，最终碰到可见舰墙；仍不把中心路线当作用户截图精确路线的复现。普通4514保留新包；4504旧包未替换。精确截图位置与全图遍历、持续性能验收继续开放。

出生坪和主坡道的物理/画面高度差很小，不能用“2m 物理与 1m 画面不一致”解释这里的明显障碍。实际4507中心路线已顺利通过出生点和主坡道分块交界，未复现空气墙；不据此更改网格、碰撞 margin 或删除隐藏碰撞。

## 实际资源数值

读取 `assets/Crater/Layout.json` 及其全部高度分片，按生产 `CraterPhysics.lua` 同一三角形对角线插值。画面取实际导出近景地形生成的 `assets/Crater/VisualHeight.bin`。表中 delta 为物理高度减画面高度，所有坐标为 H5 源坐标米，Native X 取反。

| 区域 | 整数采样范围 X/Z | 样本 | 最大 delta | 最小 delta | 高于画面20cm |
| --- | --- | ---: | ---: | ---: | ---: |
| 出生坪 | [-28,28] / [-258,-210] | 2793 | 0 | 0 | 0 |
| 主坡道走廊 | [-30,30] / [-234,-175] | 3660 | +0.049675m | -0.049018m | 0 |
| 西侧坡道区域 | [30,74] / [-245,-195] | 2295 | +0.296211m | -1.019937m | 9 |
| 东侧坡道区域 | [-74,-30] / [-245,-195] | 2295 | +0.403211m | -0.511461m | 20 |
| 南陨坑坡道区域 | [-30,30] / [-155,-68] | 5368 | +0.349946m | -1.121204m | 10 |

侧坡区域包含道路旁地形，不把区域最大差值直接当作路面障碍。整数顶点检查也不替代车身扫掠、Bullet 接触及非整数坐标验证。

原始结果及输入 SHA-256：`evidence/crater-spawn-collision-offline-2026-10-17.json`。重跑工具保留在 `.tmp/crater-spawn-height-audit.cjs`，命令 `node .tmp/crater-spawn-height-audit.cjs`。

## 10/15 冻结基线核对

源仓库 `D:/Rino_Project/Vox`，基线 `b276064942ae09c0227ec28d4cfda1d5ff006455`。以下文件相对该基线的 `git diff` 为空：

- `shared/drive/terrain.js`、`shared/drive/trackSim.js`
- `three/src/terrain/terrainMesh.js`、`three/src/terrain/terrainCache.js`
- `shared/battle/outpost.js`

该基线本身使用2m物理高度网格、1m画面网格并添加画面细节噪声。因此网格间距不同是原版已有设计。H5 `trackSim.js:43` 对完整地形三角网格使用 Rapier `FIX_INTERNAL_EDGES`；`terrain.js:57` 同样记录了三角内棱卡轮/底盘问题及该处理。

## 接缝候选与最小实测

UrhoX `scripts/drive/CraterPhysics.lua:22` 每32个2m格划分一个地形刚体，即64m分块，合计100块。出生位置源坐标 `(0,6,-234)` 的 `x=0` 已在分块边界，沿主坡直行经过 `(0,-192)` 四块交界：

- `Terrain_128_32`、`Terrain_160_32`
- `Terrain_128_64`、`Terrain_160_64`

H5 这里是单个完整地形三角网格。当前未确认 UrhoX/Bullet 在 `SetCustomTriangleMesh` 内部如何处理内棱，也没有证明该接缝实际阻车，不能仅据 API 差别改碰撞。

4507旧冻结B包实际出生点持W20秒完成，`evidence/debug-settings-1792178064431/` 为 PASS/CLOSED、运行/HTTP错误0。第2秒 `(0,4.203,-204.344)` 速度23.18m/s，第3秒 `(0.005,-0.909,-178.869)` 速度26.48m/s，已跨过 `(0,-192)` 交界；第7秒到 `(0.088,-13.064,-62.023)`，第8秒后停于 `(0.572,-12.994,-40.209)`。root 实看 `drive-10.png`，最后面对的是可见舰体实墙。测试完成不代表全图无空气墙，也没有覆盖用户蓝图和侧坡路线。

新包 `manifest-c881928c` 的设置标记加入 PlayerMarker，显式点击时记录源坐标、姿态及5条排除自身的前/低/侧向射线，命中记录含 collider、节点名、碰撞层和owner。大厅与试车场已实际保存到本地collector且无捕获错误，证据 `evidence/debug-settings-1792178279500/trial-marker.json`。后续以用户实际卡点的标记确认具体 Hull/Boulder/Terrain，未收到该点前保持问题 OPEN。

c881实际重复中心路线 `evidence/debug-settings-1792178391418/` 仍顺利通过，第三秒 `(0.002,-0.831,-179.330)`、26.48m/s。当前会话控制台marker记录最终卡点 `(0.562,-12.996,-40.145)`，前低射线0.117m命中 `Hull18`、两侧命中 `Hull2`，与可见舰体实墙一致。该轮工具误选旧collector会话的 `trial-marker.json` 已识别，原文件保留；正确控制台记录另存 `crater-marker-verified.json`，不声称该条已验证传输落盘。QA工具现按启动前session集合隔离并核对当前map；最终3aca包新会话的大厅/试车标记落盘通过，证据 `evidence/debug-settings-1792178742748/`。空气墙未因此签收。

## 其他排除与边界

此前静态结构离线射线对照覆盖1879个有效结构碰撞体、118个可见结构网格、147条导航边中心线，未发现碰撞先于可见结构超过0.5m的候选。该检查未包含地形、散布石头、车身体积、Bullet margin 和真实接触，不能据此宣布没有空气墙。

不建议先把全图碰撞加密到1m：主出生路线的高度证据不支持这样做，同时会增加碰撞数据、构建时间和内存。最小改动必须由实际卡点对象决定。

## 出生两侧道路定点复核

后续离线复核把结构碰撞/画面射线增加到419条；出生相关导航道路分别取中心、左右偏移，以及高于道路0.25/0.6/1/1.5/2m的射线。1879个有效结构碰撞体和118个可见结构网格中，仍未发现物理先于画面超过0.25m的候选。该数学检查不含车身体积、Bullet margin、地形接触、实际视口剔除或遮挡，不能替代侧坡实驾。

同时对实际 `assets/Scenes/Crater.xml` 的 `fortress_own/ship/props/rocks/debris` 共119个节点，核对导出源p/q/s到Native的镜像变换及显式禁用标志，0差异；未发现这些节点发生坐标或缩放反转的证据。

出生及侧坡邻域 `|x|<85,z∈(-270,-165)` 中，半径达到物理创建阈值1.6m的散布石头只有 `Boulder20`：源中心 `(75.8895,12.0665,-231.7840)`，半径1.8008m。它被生产 `TerrainObstacles.Classify` 分到 `0x1000`、mask `0xfffd`，排除layer2车体；支撑mask `0x6fff`也排除它。不能仅因普通查询射线命中它就宣布它会阻车。建筑 `CameraSurface` 代理为trigger，游戏Space射线也忽略trigger，没有推动车体的路径。

证据 `evidence/crater-spawn-sides-offline-2026-10-17.json`；临时复核工具 `.tmp/crater-road-geometry-audit.mjs` 与 `.tmp/crater-spawn-transform-audit.py`。没有修改正式碰撞、启动硬件测试或得到新的空气墙根因。

尚可实测的两条源导航路线为西侧 `bY(0,6,-252)→bWt(41.6,6,-239.9)→bWb(62.4,0.2200,-206.1)→sW(95,-2.5239,-172)`，东侧 `bY→bEt(-41.6,6,-239.9)→bEb(-62.4,-0.9042,-206.1)→sE(-110,0.7958,-160)`。应沿作者道路走，不把穿过可见基地墙的直线捷径算为空气墙；需要用户实际卡点标记后再决定是否优先跑其中一路。

## 新截图后的实际入口修正

以上“没有发现”的结论只覆盖当时道路采样，不能排除用户随后提供的岩柱、金属斜道旁卡点。新截图为 `codex-clipboard-00367f18-9285-4a9f-96b1-cddd85bbeff1.png`，与旧中心路线终点的可见舰墙不同。

进一步发现此前只比较了原始 `buildOutpostLayout()`，遗漏 H5 的真实驾驶入口处理。冻结 `b2760649` 的 `three/src/drive/testDrive.js:495` 在 `_useWorld('crater')` 删除 `rock`、`spire`、`detail/module=rocks` 以及 `GHOST_BLOCKS`；第498行把实际 rocks/debris 画面模型按世界变换烘成三角碰撞，`shared/drive/terrain.js:58` 用这些三角面建立碰撞。源码注明这是10月9日和12日修复空气墙、凸包填满岩脚凹槽的结果。UrhoX 仅迁移了原始布局和凸包，未迁移这段实际入口。因此“原始1910个block相同”不能解释为运行碰撞一致。

精确几何候选：`Hull837/mesa.004` 源 `(17.30360094,2,-166.50968318)` 的凸包表面比同方向实际可见岩面提前1.495904m，距离最近真实三角面1.440296m。Hull837–840所有凸包顶点到视觉面的平均距离约3.2–3.6cm、最大9.7cm，说明整体位置基本一致，主要差异是凸包平面封住凹槽。另有 `Hull190–192` 旧spire方盒叠加 `Hull892/spire.004`；两者都在原始H5布局中，但真实H5入口会全部过滤后换成视觉三角面。

## 对齐实际入口的实现与边界

新增 `scripts/drive/CraterMeshCollision.lua` 和 `assets/Crater/DrivingCollision.json`。离线工具 `tools/migration/derive-crater-driving-collision.py` 核验冻结源文件后执行真实入口的过滤语句，导出61个ghost key与1613个原始1基排除索引。原布局数组不删除、不重排，方便保留Hull编号诊断。world没有visual节点时也可直接用离线描述构建碰撞；EnginePit禁止调用。

描述来自实际 `assets/Scenes/Crater.xml` 的rocks/debris静态模型和 `Materials.json`，按H5排除fx/shield/glow，保留世界位置、四元数和缩放。复用现有预载模型279–288，共10模型、147264三角、现有模型文件20286232字节；没有新增一份模型或任意减面。碰撞静态layer1、摩擦0.8，与H5当前大岩体组一致。JSON SHA-256为 `13a7b36bafb0efdca9a13b05263151b71db95d648c38a5d8600fea1a83db33e2`。生成工具 `--check` 和局部diff格式检查通过，独立验证由另一agent执行。

这是碰撞一致性修复，不是已证明的性能提升。逐模型checkpoint可把构建分帧，但两块主岩模型分别57780/74696三角，单次引擎BVH构建仍可能有尖峰，必须单独实测。不能据body数减少就宣布FPS提升或骁龙845验收通过。

Native独立接触探针初步结果归档于 `.tmp/crater-contacts-1017-a1/`：相同GT源 `(-57,-202)` 沿+Z，旧碰撞前进7.927m后停，新视觉碰撞前进89.009m且未接触该岩体，实证至少一处旧方盒空气墙已消除。但mesa的x11.2/x14路线仍接触实际 `DrivingSurface_314`；这些路径不能当作可穿越道路。x32原凸包漏挡的地方新模型也补回真实岩面，因此不能只用“走得更远”判断正确，更不能宣称新截图卡点已经全部解决。新切线短窗候选已交Native实测，最终浏览器现场及用户当前卡点仍待确认。
