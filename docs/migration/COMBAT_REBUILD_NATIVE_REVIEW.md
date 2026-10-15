# 伤车重建 native 热点只读复核

2026-10-15，固定10月14日源。本轮只读分析，没有修改Vehicle / Debris / Suspension生产逻辑，也没有把调用数量推断当实测耗时。

## 当前链路

- `CarUnit.Flush:348–381` 在同一固定步内：保存位姿/速度 → 删除断连零件并生成碎片 → Spec.Build → Dispose旧车 → Build新车 → SetState。保留同一步碰撞及动量语义，不能把这条任意拆到后面帧。
- `Vehicle.init:34–51` 每个box/hull各创建CollisionShape；履带带h.shape时另建CustomGeometry并逐顶点DefineVertex、Commit，再SetCustomConvexHull。普通轮胎另建圆柱。质量更新已用Disable/Enable包住，不能再把“集中质量更新”列为未做优化。
- `Vehicle.SetState:96–108` 恢复位置/旋转/线速度/角速度、转轴/机械足，再Sample全部车轮。
- `Vehicle.Step:158` 随后再次Sample全部轮悬挂；但是两个Sample之间可能发生其他车重建、碎片产生/删除、推车/转轴位姿变化，不能仅凭“同固定步”删除其中一次。
- `Debris.Spawn:19–44` 每组运行Spec.Debris、合并方块、按box/hull创建CollisionShape和轮圆柱、注册刚体、用新COM采样旧速度、设置随机角速度。碎片保持5秒/最多60片。改上限/寿命/碰撞层会改变玩法，本轮不建议当作无损优化。

## 保持语义的候选

1. **优先：缓存不可变履带点云模板**。`VehicleSpec.TrackShape:40–59` 的输入仅类型Geometry，反复走每个轮16段×lane、float32 pack/unpack；可按Geometry表弱键缓存输出。输出作为只读几何，后续rotor只移动center/quat，不修改shape。可同源逐float比较，覆盖所有履带/朝向；这个减少Lua运算，但不保证减少Bullet cooking。
2. **小而确定：native setter批量化**。目前SetState连续setTranslation/setRotation，以及ApplyRotors对同CollisionShape分别position和rotation；类型声明已提供RigidBody:SetTransform和CollisionShape:SetTransform。可用一次native调用同时设置相同transform，减少跨Lua/native次数。必须核Body包装器缓存失效、是否wake及compound更新次数，原生对照位置/速度/惯性/射线结果后再落。
3. **只在单次Sample内：getter作用域缓存**。Sample开始的rotation/translation跨轴取值可用现有beginReadScope，后续velocityAtPoint依赖速度不缓存；不跨轮冲量、不跨native重建、不跨物理步。已有Vehicle.Step的readScope，收益主要在SetState/Place直接调用Sample。
4. **更大风险：缓存引擎凸包几何**。API支持SetConvexHull(Model)和SetCustomConvexHull(CustomGeometry)，文档没有保证相同geometry会复用Bullet cooking。可以离线生成与原点云逐float一致的共享Model或保留geometry模板，但是否与CustomGeometry版完全同碰撞结果需原生测。不能凭Urho3D经验保证缓存存在或无差异。

## 不推荐直接做

- 不把spec缓存按blueprint对象身份复用：受损/恢复和rotor会变；必须由精确结构版本/不可变描述确定。
- 不把车或碎片CollisionShape/刚体对象跨单位直接共享。它们包含node、owner、compound与当前姿态；简单复用会把伤车射线归属和COM搞错。
- 不删除SetState的Sample，除非能提供包含世界碰撞版本、所有相关动态body变换与当前速度的精确失效键；目前项目没有这套键。仅按time或fixed-step缓存不成立。
- 不池化复用仍在碰撞世界中的刚体：会保留contact manifold、休眠/CCD等状态。节点池可以减少alloc但不能自动证明动力学一致。

## 需要的实际测量

当前已知历史伤车Flush约416ms；最新6车无破坏路线没有触发Flush，不能归因到native cooking。本轮真实破坏应拆：Spec.Build、每类CollisionShape创建/Set、凸包Define/Commit/cook、EnableMassUpdate、Vehicle.SetState/Sample、Debris.Spec/Shapes，以及渲染模型重建。先按构造调用归因，再选上述候选，不能给未测比例承诺。

## 同时确认的击毁反馈遗漏

- 冻结 `trackSim.recordKill:152–157` 和竞技 `matchSession._patchSim:798–802` 都独立发amount0/killed的damage事件；testDrive:1394在没有旧pops时创建聚合，因此延迟坠毁也有击杀反馈。
- 目标旧TrackWorld只给既有pending置killed，pending在.25秒后被UI清理，会丢击杀粒子/音效/定格。
- 经root单独授权，唯一生产增量改为 `metrics:Damage(self.time,unit,0,pos,true)`。保留source过滤，不增加伤害，实际RecordKill→Metrics→DriveOverlay隔离链验证有/无pending、下一帧不重复、300分/音效/ConfirmKill各一次。19,904项离线检查通过；真实Web仍由root验。
