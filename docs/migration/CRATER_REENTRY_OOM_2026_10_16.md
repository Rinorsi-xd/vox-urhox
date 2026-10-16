# 592c0077 陨坑重复入场 OOM 只读定位

后续真实复验：41e4025e 已执行相同三次入场链路并完整返回，`evidence/combat-performance-2026-10-15T16-33-58-904Z` 结果 MEASURED、运行错误0，观战/MVP/真实新队列及新阵容第三次加载成功。本次未复现以下旧OOM；不删除旧FAIL，也不保证任意重入次数或其他模式。该包去掉场景 XMLFile 重复DOM，并在重地图加载前退休旧厅；两项同时改变且阵容不同，无法单独量化归因。采样固定WASM容量约1640MiB，不是使用量/空闲量。首次加载仍有4701.620ms最大帧，局内严重性能仍FAIL。

证据目录：`docs/migration/evidence/combat-performance-2026-10-15T15-52-54-887Z`。包为592c0077，内容身份已独立核对。此次没有修改production，没有启动额外GPU/native/Web。

## 已确认的故障位置

实际是**第三次**陨坑加载崩溃：首次动作10项通过并确认退出计一次败局；第二次正常入场（capture sequence=2），完成QA核心破坏、观战、MVP、结果按钮；点击再来一局后正常回厅释放、走真实queue/found/roster，第三次陨坑在原生异步scene加载阶段OOM。

| console.log 行 | 本地时间 | 阶段 | cache bytes | Model bytes | Array bytes | Image bytes |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| 2387 | 23:56:48.305 | 首次回厅完成 | 79375427 | 16309957 | 0 | 0 |
| 2485 | 23:57:42.763 | 第二次入场加载页关闭 | - | - | - | - |
| 2638 | 23:57:52.492 | 第二局MVP done | 224781061 | 64403628 | 67109584 | 16777216 |
| 2658 | 23:57:55.304 | 回厅刚提交，待延迟释放 | 248204350 | 78574452 | 67109584 | 16777216 |
| 2661 | 23:57:56.271 | 回厅延迟释放完成 | 82887122 | 16309957 | 0 | 0 |
| 2669 | 23:57:58.088 | 再匹配真实queue | 83655130 | 16309957 | 0 | 0 |
| 2683 | 23:58:09.240 | 第三次albedo暖加载完成 | 117334580 | - | 33554792 | 0 |
| 2685 | 23:58:10.284 | 第三次nra暖加载完成 | 150889372 | - | 67109584 | 0 |
| 2687 | 23:58:10.606 | scene开始 | 153926123 | 16309957 | 67109584 | 0 |
| 2689 | 23:58:12.417 | scene进度0.50 | 177581887 | 39899657 | 67109584 | 0 |
| 2691 | 23:58:13.283 | scene进度0.55 | 188740832 | 50334436 | 67109584 | 0 |
| 2692 | 无时间前缀 | Aborted(OOM) | - | - | - | - |

最后探针 `loading.phase=scene`、`prepareFrames=0`、`prepareStageMax={}`。`prepareStage=world`只是Loader初始化占位，**不是已经进入物理构建**；没有第三次CraterPhysics日志。新session、车辆、HUD和新小地图尚未创建。

## 已排除与尚未证明的原因

- 旧陨坑GPU数组/旧Model驻留不能作为此次证据支持的根因：回厅后 arrayBytes=0、imageBytes=0、craterModelResident=false，Model回到16309957，retiredTargets=0。
- 旧trial被探针保留引用，但已观测scene/world/effects/view/hud全部false；小地图texture/base/vg/capture全部false；capture gate/scene/worker/texture/result/node/camera/image/uploadTexture均false且disposed=true。
- 第二次回厅cache较首次仅增加3511695字节，Lua回到39018.58KiB，不能据此宣称整张旧地图或16MB小地图CPU像素泄漏。
- 纹理暖加载两组各33554792字节，且每组间隔4帧；在OOM前已经完成。最后scene渲染批次为0，不是正在绘制战斗导致OOM。
- ResourceCache计数**不是WASM整个堆**。它不覆盖原生scene对象、下载VFS、解码/上传临时缓冲、物理allocator及renderer内部缓存。没有实际WASM已用/容量/增长记录，也没有失败malloc栈，无法把确切剩余堆、碎片化或原生泄漏认定为已定位。

## 具体所有权与最小修复建议

### A. 先消除Web大地图候选与旧机库同时驻留的窗口

`HangarApp.EnterTrial`保留self.scene/hangar/car/previews，直到候选scene、物理、session全部完成并Activate才Dispose旧机库（HangarApp.lua约330–348）。而LoadingFlow已完整遮住机库。第三次scene加载时旧机库依然占至少16309957字节Model；纹理数组又先加载67109584字节，然后LoadAsyncXML连续加载陨坑Model，形成确定的旧/新双场景峰值。具体最多能释放多少必须用实际cache+WASM堆测，不能将16.3MB直接等同全部可回收内存。

建议仅在Web重地图路径、加载页真实呈现且页面资源ready之后设一个“释放旧局外”的明确边界：停止旧viewport/反射/预览、dispose旧机库car/hangar/scene、clear app引用，等renderer retirement及非强制cache sweep完成，再开始纹理暖加载/ReadScene。若候选失败，走统一机库重新加载恢复入口；不能继续使用已dispose的self.scene或原“保留机库”的错误分支。不要force释放当前候选使用资源。需用故意加载失败夹具检查回厅恢复。

这比改变物理、缩模型或改画面更直接针对本次确定的峰值；尚未实测，不能保证单独解决WASM堆泄漏。

### B. 去掉SceneLoader重复解析场景XML的所有权

`SceneLoader.ReadScene`先GetResourceAsync(XMLFile)读/解析场景，再cache:GetFile(path)交LoadAsyncXML重新解析（SceneLoader.lua73–95）。最后探针xmlBytes=3037888，仍有额外ResourceCache DOM；sourceFile保留到async完成。已知下载gate先确认资源可用，Web路径可以直接GetFile→LoadAsyncXML并保留File到async完成，避免额外XMLFile DOM。必须核对引擎封装的GetFile挂载语义，保留Cancel/Fail销毁sourceFile与StopAsyncLoading。该改动明确省去多余DOM，但不能把它单独声称为OOM根因或完整修复。

### C. 独立小优化，不是此次scene阶段OOM根因

`MatchMapShot.LoadBaked`从cache加载Image→Texture2D.SetData后没有释放CPU Image资源缓存（MatchMapShot.lua69–74），活动对局imageBytes=16777216，回厅后才随普通sweep释放。处理上传完成/renderer staging安全边界后释放cache里的`Crater/Minimap.bin` Image，能减少局内CPU缓存驻留；需要先证实SetData复制/上传生命周期，不能在借用原生指针时立即Dispose。因为第三次OOM时imageBytes已经0，它只是次级优化。

## 下一次验证的必要证据

新包用同一条真实路线，至少连续三次进入/回厅并再来；记录每次旧场景释放前后、纹理组前后、scene加载每片的ResourceCache、Lua和实际WASM堆容量/已用值。故意让第三次scene加载失败，确认回厅恢复。性能与音频回归仍需真实运行；不重跑无关G0矩阵。

## 验收工具防挂修复

只在工具中增加致命Aborted/OOM/out-of-memory与page crash处理：同步写已有report，保留最后完成的rAF/GL checkpoint并标truncated，再只关闭本工具browser以打断pending keyboard/F8。每个end(name)持久化frame样本；fatal后不再screenshot/evaluate；非fatal最终read限5秒，失败保留旧checkpoint而非覆盖空frames。

`node tools/migration/check-combat-fatal-fixture.cjs`：实际工具经内存browser/fs替身执行，**13/13 PASS**；`node --check tools/migration/check-combat-performance-web.cjs`通过。未开浏览器或GPU。旧OOM证据保留原缺失采样状态，不补造其rAF。
