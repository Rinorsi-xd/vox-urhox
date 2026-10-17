# 实际八车 Web CPU 取证

日期：2026-10-17。基线沿用 1016/f94827b2、H5 10/15 b2760649；实际派生包来自 0baeef97。root 串行运行浏览器，本子线仅离线分析、增加隔离取证工具，没有修改生产算法、启动 Runtime 或并跑硬件。

身份冻结如下，不能只用当前分支名替代实际构建：

- H5 source branch `2026-10-15`，commit `b276064942ae09c0227ec28d4cfda1d5ff006455`，source content SHA256 `edd9d0de1b29843c739f0dfd13eb0086977d6f3b1422954f5c8cf31085232d68`。
- UrhoX target branch `1016`，commit `f94827b26fc12b707e6d6904d093e16358caaf41`；存在未提交迁移修改，所以此提交号不能完整表示运行文件。
- 生产冻结 `.tmp/outgame-cached-1792206583227/identity.json`，base manifest `0baeef97`，549份Lua的fingerprint `ef2e30f211a85a1fbe1191b2233539b3e9af21718f1533e415b4554ae508f132`。
- 本次实际派生 `.tmp/monitor-combat-heightfield-0bae-a/identity.json`，served manifest `8f3e398d`，保留生产模块、原监控和三段粗计时，main仅追加隔离QA入口；生产main SHA256 `9de4747691f59aa1e5ffa2159308955d4bca0b57e520b6a3fa361bed7fa16987`，QA后缀 `ba44de555cd206f2ed7b7a6efab58cdc7e00257b1226740eef094b4cb18510ab`。
- 实际QA服务4581，runner53379，证据 `evidence/monitor-combat-trace-0bae-a/`。root已直接查看after-combat/returned截图；普通预览4584保留。

## 已确定的范围

`evidence/monitor-combat-trace-0bae-a/` 的真实公开八车流程 PASS/CLOSED、exit0，运行与 HTTP 错误为 0，1049 shots / 1740 world hits、玩家伤害1330、真实零件损失，公开返厅。生产监控的1042完整帧平均43.256ms、P95 76ms、最大128ms、21次大于80ms。

本轮额外启用1ms CDP CPU采样和详细trace，204,074,935字节trace；与普通轮次的35.086ms不构成优化A/B，不能声称此差值是生产回退或采样器的精确开销。未做同阵容、同伤损时序、同工作量的监控开关对照。

1040个完整 `MainLoop_runner` 回调均有Chrome实际线程CPU字段：平均墙钟42.404ms、线程CPU40.954ms、offCPU1.450ms。15个大于80ms的回调，线程CPU均约77至82ms；最长回调84.807ms，其中CPU81.851ms。这证明本次详细取证窗口主要受浏览器主线程CPU执行约束，不能将数十毫秒差额直接解释成GPU等待。这里是回调窗口，不是生产Update到下一Update的完整帧间隔。

实际可见V8 GC事件的主线程时间并集47.533ms，最大事件9.205ms；已命名GL查询/等待事件并集2.257ms、最大0.038ms。它们不足以解释全窗数万毫秒主线程CPU。V8事件不包含WASM内Lua GC；类别清单接口返回空数组，但原始trace实际包含V8 GC等类别，因此“类别未列出”不代表该事件没有采集。

## 已找到的执行热点

原始CPUprofile共有30,761个统计样本、时长45,477.057ms。按函数名合并不同调用树节点后的自权重：

| 函数 | 样本权重ms | 占非负样本权重 | 能确认的名称 |
| --- | ---: | ---: | --- |
| wasm-function[9978] | 7044.904 | 15.491% | 无符号，不能猜成某个Lua方法或GC |
| wasm-function[3264] | 3028.006 | 6.658% | 无符号 |
| wasm-function[767] | 2218.055 | 4.877% | malloc |
| wasm-function[909] | 2189.638 | 4.815% | 无符号 |
| wasm-function[629] | 1894.802 | 4.167% | free |

malloc/free合计约9.04%的统计自权重，给出了继续定位原生分配/释放调用者的实际依据；不代表Lua GC已经确诊，也不代表清除所有分配可获得9.04%整局帧率收益。统计权重不是精确函数CPU耗时。

名称映射来自当前服务目录的实际WASM export索引和JS赋值：`_malloc=wasmExports["yk"]`，yk导出function767；`_free=wasmExports["xk"]`，xk导出function629。top30的profile字节偏移均严格位于本地对应WASM function body内。WASM SHA256为 `4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765`，JS为 `260edf443545a4531672291c3cfdddd73aee0d864cd8108b81b7d6422491884f`；WASM没有custom/name section，不能从这个包中还原其余C++函数名。此分析没有编译、实例化或执行WASM。服务器配置指向该目录，实际采样URL相同；本子线没有另取浏览器已加载响应的字节哈希。

应交引擎侧符号化的首要位置：function9978/body offset2316955，function3264/627701，function909/196519。保留完整CPUprofile调用树，不能仅交这三个孤立数字。

原profile存在两个负timeDelta（样本14120为-12us、24944为-10us，均program节点）；样本数保留，负值不参与权重，并在derived结果显式记录。原始profile未修改。

## 与已有Lua分段的关系

普通0bae实际轮次已记录：BeforeStep inclusive10.121ms/帧，其中Vehicle.Step5.270ms；独占Effects2.131、AI1.815、物理1.613、武器1.550、Environment1.481、全车DriveView1.173ms/帧。这些是另一轮实际工作量下的墙钟，不能与本轮CPUprofile比例拼成同一帧，父子也不能相加。

已知确定长帧路径包括同步重生装配：普通0bae engineFrame4464为85ms、BeforeStep self58ms，同时AddPart152次/零件增加152。它可以作为独立候选优化入口，但不能解释另十个随机散布长帧。先前射线路径分配归因和本轮malloc/free采样可以支持继续量其调用者，仍需同工作量正常GC A/B证明耗时收益；之前Cylinder减少分配但无耗时收益的拒绝结论不变。

## 工具版本差异与原始完整性

root启动collector时，该进程加载的版本早于后续“实际clock_sync唯一性校验”增强。因此原metadata没有`clockSyncVerified`，当前严格analyzer首次拒绝；没有修改原metadata冒充新版运行。

`recover-monitor-combat-clock.cjs` 读取raw trace，校验四个原syncId均精确出现一次、顺序一致、实际marker晚于对应Performance Timestamp且延迟低于10ms（实际0.755至0.903ms），保存独立 `independent-clock-sync-verification.json`。该文件同时记录旧collector哈希、当前collector/analyzer哈希与四份raw输入哈希。仅在内存derived metadata中补入已验证字段后调用原严格analyzer，生成 `combat-trace-attribution-derived.json`，未降低断言。epoch/trace误差区间2.189ms。

21条长帧日志能够明确锚定发出该日志的回调，另1条因窗口边界拒绝。生产Finalize在下一BeginFrame发出上一帧记录，所以没有把该发出回调的CPU/GC错配为上一帧，也没有用相邻稀疏锚点推算其他帧。

## 产物与后续

- `combat-trace-attribution-derived.json`：实际线程CPU/等待/V8 GC/GL事件、全部长回调和明确证据边界。
- `independent-clock-sync-verification.json`：raw四锚点恢复、版本差异及输入SHA。
- `independent-wasm-profile-v2.json`：完整统计聚合、真实malloc/free映射、函数offset、调用栈、负delta记录。v1初步结果保留。
- `recover-monitor-combat-clock.cjs`、`summarize-combat-wasm.cjs`：可复算离线工具。

下一项有效动作是对这份确切WASM提供符号，将9978/3264/909及malloc/free调用者落到实际引擎函数；同步重生单独做正常GC同负载候选对照。不能继续把随机长调用归因为AI算法或GPU，也不能宣称手机已达标。845/TapTap长时间稳定30FPS、普通Web整局同负载A/B与全部长帧成因仍OPEN。
