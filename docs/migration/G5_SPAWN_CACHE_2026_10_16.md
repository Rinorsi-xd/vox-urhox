# G5 无尽出兵规格复用

## 接续与范围

后续统一包046debe2包含2661，实际五波/补给/暂停改装29项PASS、运行错误0；浏览器已正常关闭。7049rAF/191帧>100ms/max4103.165ms，性能FAIL；有用户编辑器并存且无受控A/B，不用此结果声称缓存网页加速。证据`evidence/endless-banner-manifest-046debe2-2026-10-15T18-22-07-300Z`，仍非自然完整战斗/手机验收。

接续4227后的G5功能批，不重开G0。源仍 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本批仅修改 `scripts/app/EndlessSession.lua`，最终SHA256 `2661cbf0e34b0a51ac2f423ec49c1808e0df37840127efe552057d488ac8572e`。沿用项目既有 `drive.SpawnSpecCache`，未修改缓存、物理、车规格计算、波次、敌人AI、伤害、掉落或源资源。

参考旧实现冻结于 `.tmp/endless-spawn-cache-before-20261016.lua`，SHA `4ed4d32b2ebd7443cde2865dead0ae2005a786ecbcf2b7d92ef04879d13273ee`，包含已完成的金币1400ms和原死亡等待提示。

## 根因与修改

原 `Spawn` 首次为半径调用 `VehicleSpec.Build`，随后 `SpawnUnit -> CarUnit.Spawn` 又构建一次；之后相同prefab每台仍完整重算。旧 `specCache` 还长期保留仅用于半径的一整份规格。

现在局内owner创建既有 `SpawnSpecCache`，首次 `SpawnRadius` 执行 `Prepare/Get`，只把数值半径保留在 `spawnRadii`。实际 `Unit.New` 收到同一scene cache，由既有 `CarUnit.Spawn` 取得独立深克隆。直接 `SpawnUnit`（QA或空投）也先走同一准备入口，无需依赖先前的普通出兵调用。原hpScale仍在各台CarUnit上应用，未进入pristine模板；出生位置和运行时的损伤/姿态不能污染模板。

`EndlessSession.Dispose` 带nil门禁释放缓存并断开owner引用、清空半径表；重复退出仍幂等。没有保留第二份完整规格缓存，也没有新增全局缓存。

## 实际检查

`tools/migration/check-endless-spawn-cache.py` / `.lua` 执行旧、新真实 `EndlessSession.Spawn/SpawnUnit/Dispose`、真实 `VehicleSpec.Build`、Blueprint、CarUnit、WeaponSystem和51个实际原敌车prefab，原生body/vehicle、driver为适配器。

- **1291/1291 PASS**，`evidence/endless-spawn-cache-offline.json`。
- 每型连续3辆实际构建数 **旧4 → 新1**，51型合计 **204 → 51**。该计数只包含前三辆主对照，不含后续损伤/直接生成夹具。
- 逐台比较完整spec、hp表/车体血量/partScale、中心出生点/偏航；队列、alive、规则时钟、nextSpawn与unitSpawn保持不变。
- 每型第一辆实际调用 `CarUnit.Damage` 打穿核心至车体0血，再修改其spec的bounds/mass/hull/weapon和独立Blueprint位置。第二辆、缓存模板与源prefab不受影响；随后同型第四辆恢复完整spec/独立满血，且不新增Build。
- 直接普通/空投 `SpawnUnit` 首次均只构建一次，第二台复用；两条路径的完整spec、出生位置、空投标记均与旧实现一致。
- 出生门占用、出兵间隔、8辆上限和空投warning/pending分支与旧实现一致；cache与相关调用不消费/重置RNG。
- 51型逐一检查实际Unit释放后Session退出：template entries清空、cache.disposed、owner引用清除、半径清空、重复Dispose安全。

最终Session SHA实际重跑既有源对照：出生呈现497、严格退休生命周期22（另执行497 setup）、横幅222、撤离/死亡入口547，全PASS，四份报告均记录本最终SHA。此前G5保险库675、拾取92、结算29的生产文件本批未改。`git diff --check`另查。

新夹具初次失败是直接比较含不同函数闭包的run表，后只比较其数据字段；另一次fixture错误把武器字段写成不存在的pos，按实际规格契约改muzzle。旧出生呈现夹具未注入新依赖导致缺global cache，已补其无关子系统的SpawnSpecCache生命周期适配器；实缓存/真实Build由本1291项独立覆盖。未改生产来迎合夹具。

## 验收边界

无GPU、完整构建、提交或上传。本次构建次数减少已实测，不代表网页帧时间提升已测得；深克隆、CarUnit自身Blueprint/Graph、物理创建、渲染warmup仍有成本。自然完整战斗/死亡复活、网页加载和持续帧率、手机/账号未验。下一统一包实际测量后才判断卡顿收益；不以旧4227或b6f的网页结果代签。
