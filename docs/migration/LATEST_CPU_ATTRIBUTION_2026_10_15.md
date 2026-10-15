# 10/15 CPU 采样归因与空扫描优化候选

本批继续当前性能问题，未重启 G0。结论：冷加载确有大量 shader status 查询与读时钟样本，但当前稳定战斗的 111–118 ms 帧时间不能据此归因为 shader 等待。战斗样本 95.755% / 97.043% 落在未符号化 WASM；必须继续做生产调用区间采样或取得同版本引擎符号才能准确分配责任。

## 输入身份与范围

- 当前：`verification/2026-10-15/manifest-d7af571f.json`，467 Lua 对应 d7af，脚本指纹 `99ac8e3ba04b01496c10f33175ce2bed8bbe724ea971f331cd2ec74ec2b3a04d`；包字段 targetCommit 为整理前父提交 ad72080，不是被测 Lua 的完整身份。
- 参照：`evidence/combat-performance-2026-10-15T13-56-49-208Z/`，`manifest-706d3d0b.json`。
- 离线分析全部 7 份当前 profile 和 4 份参照 profile。原始文件逐个计算 SHA256，并在读取完成后复核未变化。结果：`analysis/latest-cpu-profiles-2026-10-15.json`。
- 两组报告均没有直接 GL 调用记录：`gl` 为空、`slowGL` 为空。CPU profile 有效，但不是 GPU 时间戳或逐调用计时。

## 实际采样结果

下表采用 profile 的 recorded timeDeltas 加权。时钟列只计叶节点 `now` / `_emscripten_get_now`；shader 列计具名 status 查询及其子树，二者类别互斥。采样时间不是精确函数耗时。

| 当前阶段 | Profile 时长 ms | 时钟叶节点 ms / 占比 | Shader status 子树 ms / 占比 |
| --- | ---: | ---: | ---: |
| 启动 | 60,559.821 | 35,416.617 / 58.482% | 3,129.713 / 5.168% |
| 首次进图 | 131,331.337 | 46,259.089 / 35.223% | 17,703.855 / 13.480% |
| 首次战斗 | 11,559.881 | 75.631 / 0.654% | 10.247 / 0.089% |
| 首次返厅 | 9,081.985 | 1,794.839 / 19.763% | 0 |
| 再次进图 | 53,964.898 | 6,969.933 / 12.916% | 0 |
| 再次战斗 | 11,576.323 | 28.396 / 0.245% | 0 |
| 再次返厅 | 8,701.807 | 1,916.348 / 22.023% | 0 |

706d 的启动时钟占比 58.966%、首次进图 37.031%；shader status 分别 4.930% / 11.630%。其战斗未符号化 WASM 占比 96.182%，shader status 仅 0.044%。两包在这个分类层面相似，不能称为本轮优化 A/B，车辆位置和 AI 状态并未控制。

当前两次战斗最重的叶节点均包含 `wasm-function[9978]`、`[3264]`、`[767]`、`[629]`。没有该引擎二进制的符号映射，所以不能把这些编号命名为 Lua、Bullet、渲染提交或某个锁。加载时 `_emscripten_get_now` 的长调用链和 `xhr.onload` 上下文也不能证明具体锁持有者。

当前实际战斗快照为 1,716 / 1,905 batches，7,631,869 / 7,717,201 triangles；`desktop=false`、`api=GLES`、自建后处理 0 层，瞬时 flashes/beams/smoke/particles 都为 0。原始报告已确认局内性能 FAIL；本报告不以采样分类修改该结论。

## 已实施的最小候选

`Space:Step` 原先每次 `PhysicsWorld:Update` 后遍历所有登记刚体，只处理 `owner.type == 'vehicle'`。`TrackWorld.NewVehicle` 随即把战斗车辆 owner 改成 `car`，因此战斗中即使登记了大量静态地面、舰体、岩石或相机刚体，这个遍历也可能完全不产生回调。

候选只在 Space 维护 vehicle owner 数量，集中通过 `SetOwner` 修改所有权。数量为零时跳过空遍历；有 vehicle 时保留原 `pairs(self.bodies)` 及回调筛选顺序。`world:Update(dt)` 仍先执行，次数、dt、引擎物理配置均不变。TrackWorld 只更换现有 owner 赋值入口。本次不改原本 car 不调用 PostStep 的行为。

实际 Lua 5.4 加载候选与 d7af Space 模块，使用 native-free PhysicsWorld / Body 替身对照：85,132 断言 PASS。1,500 静态体和 6 辆已变为 car 的车辆，在 600 次物理更新中，原版扫描访问 903,600 次，候选 0 次；native Update 日志相同。涵盖登记、vehicle/car/nil 转换、缺 ref、同类型转换、同 ID 重登记、删除、重复删除、Update 中修改 owner、未知 owner 失败、实际 TrackWorld.NewVehicle、Dispose 与保留 wrapper 失效。证据在 `evidence/space-owner-guard-offline.json`。

候选 SHA256：

| 文件 | SHA256 |
| --- | --- |
| `scripts/physics/Space.lua` | `37cadd9d962a10531c8230b8f9f7563e367a19107c6bde45594d0ea2fff6e821` |
| `scripts/drive/TrackWorld.lua` | `c01e5363cdba4b20930ad1ac168b8229b6270959e0dffc4d0f1d209c740862f7` |

这证明 Lua 行为与减少空扫描，不证明 Web、Bullet 或真机性能收益。本候选尚未进入最终同包 Web 性能验收。

## 接续边界

1. 下一统一包对 Space.Step / world.Update / Vehicle PostStep 与渲染阶段分别计时，再测真实公开入口战斗；不能直接把上述 WASM 总量算作 Lua 时间。
2. CraterPhysics 每次建精确地形几何和三角碰撞，已有协程让步；离线烘焙碰撞仍是独立较大改动，本批未实施。
3. Space.Raycast 读取多命中后过滤 own body、trigger 和 owner 类型；不能为了最近命中省时丢弃这些语义。
4. Body / Vehicle 的读取缓存已经存在于 d7af，不算本批新收益；战斗 CarUnit 血量已有 O(1) 路径，不能再列为逐零件求和热点。
5. 散布剔除与渲染实验由另一并发任务持有 GPU；本批没有启动浏览器、原生窗口或 GPU 工作。

## 复现

```powershell
node tools/migration/analyze-latest-cpu-profiles.cjs docs/migration/verification/2026-10-15 docs/migration/evidence/combat-performance-2026-10-15T13-56-49-208Z docs/migration/analysis/latest-cpu-profiles-2026-10-15.json
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-space-owner-guard.py
```

Lua 测试使用本机 `.tmp/nav-python-deps` 的 `lupa.lua54`，默认对照不可变缓存 `.tmp/outgame-cached-1792074566364`。它们是本机依赖与对照输入，不是随生产游戏打包的资源。
