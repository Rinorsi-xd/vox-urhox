# 蝎型战车课程失败：源与目标只读诊断

固定源 `b276064942ae09c0227ec28d4cfda1d5ff006455`，目录 `.tmp/outgame-source-2026-10-15T12-35-57-243Z`。目标实际失败证据为 `evidence/practice-course-web-manifest-d5da34be-2026-10-16T02-33-27-644Z/report.json`。本诊断没有修改车辆、课程、输入、物理、probe 或验收阈值，没有运行浏览器/GPU、构建、提交、上传。

## 结论与边界

蝎型车在固定源的相同课程也出现初始刚体穿透，抓墙显式油门只前进约 0.683m 后受阻；同一辆源蝎型车在平地前进约 19.493m，小型源六足 T5 在同一抓墙/山坡课程分别前进约 16.400m/22.903m。证据支持“原课程与这辆大车的车体/腿安装布局不相容”，不能把当前目标的 0.668m 失败归因于按钮回调，也不能声称源与目标的完整动力学已一致。

另有独立的目标移植缺口：CarUnit 路径漏调 Vehicle.PostStep。它可能影响落地抗弹起，但源版已经执行 PostStep 仍在该山坡弹飞，不能把补回这个调用说成课程失败的完整修复。

## 目标实际运行

两按钮均传到原坐标、显示原提示，并恢复真实浏览器 pointer lock。提示截图已由 root 视觉检查。抓墙 W 前后 body XZ 从 `[-66.00032,-31.83156]` 到 `[-65.99598,-31.16325]`，位移 `0.668324m`，未达到既定 `>1m`。此时 available=8、contacts=6、authority=1，墙预判和爬墙均 false；136 个固定步、droppedSeconds=0。因此不是失去腿支撑或丢失固定步。现有 probe 不记录 W/油门标量，不能把真实 throttle=1 当作已观测事实。

山坡捕获时 bodyY=10.77836、available=contacts=authority=0；W 后虽然 XZ 1.108m，但同时落到 bodyY=-0.8664。该距离混合了无支撑下落，不能签为正常驾驶通过。

## 实际源与目标规格

源执行 `Blueprint -> buildScorpion -> buildVehicleSpec`；目标执行真实 `construction.Prefab.Create -> drive.VehicleSpec.Build`，只把 ResourceData 桥接到实际 JSON，用 Lua 5.4，不模拟目标原生物理。

| 项目 | 固定源实际计算 | 当前 Lua 实际计算 |
|---|---|---|
| 零件/质量 | 1557 / 9444kg | 1557 / 9444kg |
| 实体碰撞 | 464 merged boxes + 8 leg mount hulls | 相同 |
| 完整 bounds min | [-9.8006711006,0.5533440113,-11.25] | 相同 |
| 完整 bounds max | [9.8006711006,16.5,18.25] | 相同 |
| bounds radius | 19.4213700168 | 相同，浮点尾差约 4e-15 |
| 实体车身 AABB min/max | [-7.75,2,-11.25] / [7.75,16.5,18.25] | 相同 |
| 两个前端实体箱体 center | [-5.5,6.75,16]、[5.5,6.75,16] | 相同 |
| 两箱体 half | [0.75,0.75,2.25] | 相同 |

完整 bounds 包含活动腿的显示范围，不能全部当实体车身；这里另算实体 boxes/hulls。八腿的安装点 Y=3.75、Z=0.5/-1.5/-3.5/-5.5，最前腿安装点比车头实体前端落后 17.75m。每腿 height=3.1926375675m、reach=10.1201642918m、load=1400kg，总11200kg，不是没有承载能力。

当前 `VehicleSpec.lua` SHA256 `76f9891bd5a58e86b31be0cdc86bbcc8c4201ccbc69a56737183cf3213e75025`；Track Manifest SHA256 `94d13747cc113404a1f3df5db3bc27848e185e9a27fa7b44025ece21a3f435c8`。

## 出生穿透证据

source `vehicle.place` 与 target `Vehicle:Place` 均以 `posY - bounds.minY + .15` 放置，课程 Y=0 时车身原点 Y=-0.4033440113。

抓墙：源 `track.js:180` 的墙 center=[-66,3,-5]、size=[17,6,20]，实际 Manifest 相同。墙 AABB X=[-74.5,-57.5]、Y=[0,6]、Z=[-15,5]。源课程出生点 `track.js:194` 为 [-66,0,-32]，两个无旋转前端实体箱体的世界 Z=[-18.25,-13.75]、Y=[5.5966559887,7.0966559887]。因此初始 Z 重叠1.25m、Y重叠0.4033440113m，两个箱体都在墙宽内。这是实体 box 对 box 的实际相交，不是腿显示 bounds 误报。

山坡：`legCourse.js` 首段 world X=[-108.5,-91.5]、Z=[-34,-24]、Y=[-.3,3.64]，第二段 Z=[-24,-16]、Y最高9.24；Manifest的顶点逐项一致。蝎型车出生 [-100,0,-41] 时实体前端到 Z=-22.75，车身跨进首段及第二段。AABB 重叠本身不足以证明楔体穿透，所以下面额外查询了实际 Rapier 接触。

源实际 `TrackSim`、实际 scorpion、实际 Rapier：Place 后执行一个 `throttle=0, steer=0, dt=1/60` 步，再对所有非sensor车体 collider 调用 `contactPairsWith` 和 `contactPair`，排除同车自身：

| 课程 | 真实刚体接触对 | manifold点数 | 负距点数 | 最小contactDist | 静态collider位置 |
|---|---:|---:|---:|---:|---|
| 抓墙 | 2 | 8 | 8 | -0.4033441544m | [-66,3,-5] |
| 山坡 | 114 | 260 | 218 | -1.6635634899m | [-100,0,-34] |

山坡各楔体共享同一 translation，不能用该位置区分第几段。负contactDist证明真实源物理重叠，但这些是源Rapier数据，不是目标原生contact数据。

## 源 CPU 对照

导入冻结源 `shared/drive/trackSim.js`、`track.js`、`physics.js`、`build/blueprint.js`、`build/prefab.js`、`drive/legFixture.js`。每例新建 TrackSim，通过 `setPlayer(bp.toJSON(),{autoRespawn:true})` 放实际玩家，执行200步，每步先 `vehicle.step(command,1/60)` 再 `sim.step(1/60)`；前65步油门0，其后135步显式油门1/steer0。位移从第65步前测到最后，总油门时间2.25秒。TrackSim实际保存姿态会执行源 `CarUnit.savePose -> vehicle.postStep`。

| 车辆/地点 | 油门阶段XZ | 结果 |
|---|---:|---|
| scorpion / 原抓墙点 | 0.6833222119m | 约第125步后停住；available8、contacts6、authority1、climbing/wallPending均false |
| scorpion / 原山坡点 | 11.0545255629m | 油门前第30步已向上28.5645m/s，Y4.7708；第60步Y19.0281；最终Y51.4470且无支撑，不算驾驶通过 |
| scorpion / 平地[0,0,-100] | 19.4929263144m | 末速度Z13.99975m/s、available8、contacts4、authority1 |
| source legCar(5) / 原抓墙点 | 16.3996038437m | 末Y5.68068、climbing=true、available6、contacts3 |
| source legCar(5) / 原山坡点 | 22.9033966064m | 末Y8.76860、available6、contacts3 |

直接油门对照消除了源测试里的浏览器按键歧义；没有消除目标probe对W标量的观测缺口。这里的2.25秒与Web脚本按键墙钟约2秒不同，不能当严格逐帧轨迹对等测试。

## 独立 PostStep 缺口

源 `shared/combat/carUnit.js:352` 在 `savePose()` 先调用 `this.vehicle.postStep()`。目标 `scripts/drive/TrackWorld.lua:80` 把车辆owner改为 `type="car"`，`scripts/physics/Space.lua:64` 只对 `type='vehicle'` 调 PostStep；目标 `scripts/combat/CarUnit.lua:170` SavePose 又没有补调。因此通过 TrackWorld 的练习/战斗车漏掉已有的 `scripts/drive/Vehicle.lua:185` 抗上弹钳制。

应作为独立移植修复验证：一物理步一次、world update后/pose保存前；跳跃、喷气、机翼、钻头排除条件保持原样。但初始重叠时 prior contact=0，源的这层钳制并不保证介入，不能把它当作出生穿透的替代解决方案。本轮未修改该路径。

## 大车适配建议（尚未实现）

1. 保留本次 scorpion 失败记录和原 `>1m` 标准。用公开导入现有 `assets/Blueprints/LegT5.json` 建立小型合法节足车的自然操作正控；这不替代蝎型车的验收。
2. 对大车先做实体碰撞扫掠/重叠校验，按当前yaw求出生安全距离。以原墙前沿-15与车头18.25计算，无余量的originZ上限是-33.25；原台阶前沿-27进一步要求originZ<=-45.25。山坡前沿-34要求originZ<=-52.25。以上仅是直线初筛，必须结合其他障碍/全车形状与静止稳定性验证，不能直接硬编码为已验证新出生点。
3. 仅后移出生点不会消除车头比前腿远17.75m的问题。当前LegControl的Extent基于腿安装点，探墙方向从COM发出、look=reach*.7+平面速*.3，巨大车头可能在腿控制器看到墙之前被实体挡住。应先明确这类超长车头是否属于支持车型：可支持则设计基于实体前沿/可达接触的探墙与过渡；不可支持则给课程明确车型约束或提供专用大车路线，不能靠加力掩盖碰撞。
4. 适配后分别验证零输入稳定、平地手动W、坡道连续支撑、墙预判/攀爬/蹬开/收腿、复位与退出；源/目标与小/大车分开记录。驾驶手感、原生接触与移动端仍需实际验收。
