# 开篇到教程交接 OOM 追踪

2026-10-16。沿用冻结 H5 基线 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`；没有重开 G0。

## 当前生产修改与验证边界

Nono canonical 路径与整对象交接已实施，并完成 CPU 验证，尚待修改后新构建的实际自然播放验收。`evidence/intro-portrait-handoff-offline.json` 为 **167 PASS**：执行实际 Widget Extend/new/setter 路由、IntroPage.Close、OpeningHost.Begin/接管检查、CommsPortrait.New/Prepare/Draw/Dispose、CommsCard.AdoptPortrait、Tutorial.Prepare、ResourceGate 和 StoryComms.Shutdown；仅 native 图形、资源与下载边界使用替身。没有从离线结果推导 OOM 已解决、语音连续或真机性能。

- 所有 Nono runtime 消费者统一查询 `Intro/Images/nono_*.png`，涵盖开篇、教程、剧情、竞技预载/通讯与任务结果。四张 canonical 图片的 SHA/像素与冻结源完全一致；没有压缩、换图或改变 shader。
- 正常签约返回时，page 将整个已暖肖像交给 Card 后才放弃所有权；host 同时检查 opening、restore owner、hall、tutorial 与其 page 身份、未 stopped、未 failed、非建造状态。复用 faces、两个 RT、两个 material 与同 VG 的两个 video handles；恢复 330×410、canvas_size 与原计时状态。首张教程卡片没有再次同步解码 faces 或创建 video handle。
- 拒绝、失败、关闭、无教程、应用停止、上下文改变、未暖完整等分支走原 Dispose；再次开篇接管会退休上一实例。20 类拒绝、重复 Close/Dispose、直接教程的下载/失败/Cancel/迟回调均已测。
- 独立审查实际复现了新接管先于语音 shared 创建时，旧 `StoryComms.Shutdown` 提前 return 会漏清 Card。已修正：shared 尚未创建也清理 Card。测试覆盖接管后立刻停止与正常 shared shutdown、重复 shutdown，所有构建的 scene/material/RT/video handle 均只释放一次，不显式 Dispose cache 所有的原图。
- 相关离线回归：通讯立绘 384、语音 fallback 71、语音 cues 222 + loading 49、登记实际 Widget 路由 53、开篇预取 58，全部 PASS，关联生产输入哈希已刷新。

旧资源导入脚本仍可能生成 `UI/Faces/nono_*`，本轮没有删除历史资源或扩展导入管线；实际 runtime 已统一 canonical。若重新导入，必须再次执行立绘字节与路径检查，不能凭旧输出目录认定在使用同图。

以下保留修改前的诊断、失败证据和候选设计；其中“未实施”指记录当时，不代表当前生产状态。

## 修改前同包自然全程失败证据

`evidence/intro-natural-web-1600x900-manifest-0bcd53d6.json` 和同名 `.log` 保留 **FAIL**：自然流程完成 35 项检查后，在 2026-10-16 03:58:18.252 教程 group 28 下载完成时再次 `Aborted(OOM)`。JSON 的 `shutdown=PENDING`、`functionality=RUNNING`、`continuity=NOT_MEASURED` 是中断时已保存状态，不是完成验收；root 确认并结束了该测试自有进程树，原失败报告未被改写。

自然路线最后回厅状态：resourceBytes=79057745、Lua=37492.53 KiB、modelBytes=16309957，arrayBytes/imageBytes/retiredTargets 均为 0。相同构建跳过路线在对应点 resourceBytes=73065511、Lua=37722.48 KiB；缓存差 5992234 字节、Lua 接近，无法从这些缓存计数唯一解释 OOM。自然路线另执行完整试驾、射击破坏、截屏漫画和 montage，可能增加的 VFS、renderer/Shader 内部驻留与临时分配尚缺测量。

因此，下面的跳过路线 PASS **不能代表本包没有 OOM，也不能关闭开篇到教程交接**。自然全程、音频连续性、真机仍未通过。

## 同包跳过路线真实复验

`evidence/intro-web-pc-manifest-0bcd53d6.json`：**PASS，30 项检查，错误 0，shutdown CLOSED**。构建目录 `.tmp/outgame-cached-1792093513966`。实际 PC 进入公开开篇，捕获三页漫画，跳至原通讯并用鼠标选择第二项，登记页在 4:3、16:10、20:9 间真实 resize，完成键盘姓名、未签名拒绝、鼠标签名、闸门、回厅与教程资源交接。

启用 `VOX_INTRO_MEMORY=1` 后，六次只读采样均完整扫描 WasmFS，没有截断：

| 检查点 | VFS 文件总字节 | 文件数 | 扫描耗时 ms |
| --- | ---: | ---: | ---: |
| hall-ready | 298177324 | 2057 | 20.74 |
| opening-ready | 549793397 | 2541 | 19.16 |
| contract | 550684611 | 2544 | 18.21 |
| gate | 550982872 | 2545 | 19.60 |
| hall-return | 551869391 | 2547 | 18.90 |
| tutorial-ready | 565487082 | 2547 | 19.42 |

本路线没有 OOM，`memory.oom` 为空。返回厅后的引擎资源为 76804784 字节，Lua 为 43730.34 KiB，arrayBytes/imageBytes/retiredTargets 均为 0。

所有采样的 `heapBytes=1719533568` 是固定 WASM **容量**，不是已用量、空闲量或峰值。VFS 文件大小也不能直接当作 WASM 已用量；下载可以写入 OPFS。23 个 worker 中 21 个采样超时，单点总体耗时约 782–806 ms，属于有插桩诊断，不能用于无插桩帧率结论。

## 旧故障与归因边界

旧 `manifest-5198310b` 的实际日志 `evidence/intro-web-pc-manifest-5198310b-baseline.log` 保留 FAIL：教程 group 28 完成后紧接 `Aborted(OOM)`。返回大厅时引擎缓存已由约 252.6 MB 降至 70.6 MB，Lua 降至约 37.7 MB，旧地图数组和 Image 均为 0；不能宣称开篇完全没有释放。

已确认开篇 `Intro/Images/nono_*` 与教程 `UI/Faces/nono_*` 是不同路径和 UUID。教程下载三张 1856×2304 立绘、18 段 OGG、7 项音效；立绘原始 RGBA 预算约 48.94 MiB，首张卡片再请求 talk/smile。此处存在重复下载和重新解码的峰值风险，但旧日志没有失败分配请求、堆已用量和 native 栈，**不能唯一归因于立绘、泄漏或碎片化**。当前两套图片已统一为冻结原图，本次未为 OOM 修改生产代码。

另一个旧 `manifest-a7d7050c` 在登记页出现自动 setter 递归导致 C stack overflow/OOM；root 已改正该调用，0bcd 的登记与 resize 实测通过。它与 519 的教程交接故障是两次不同故障，不合并归因。

## 尚未证明

此次 PC 跳过路线没有证明自然全程音频连续、所有开篇互动、任意次数重入或手机真机性能。原 519 FAIL、a7 FAIL、0bcd 跳过路线 PASS 和 0bcd 自然路线 FAIL 全部保留，不互相替代。

## 修改前诊断与无损候选记录

自然测试工具已加入可选 `VOX_INTRO_MEMORY=1`，复用 `web-memory-probe.cjs`，在 hall-ready 安装失败扩堆捕捉，记录 opening-ready、contract、gate、hall-return、tutorial-ready 和失败检查点；每点立即保存 JSON，失败请求记录 requested、固定容量与 JS/WASM 栈。单点 2 秒超时，不能将这些插桩运行的帧时间作为无插桩性能验收。默认关闭，原自然流程和连续性判定没有放宽。

优先候选是统一 Nono 立绘 canonical 路径，并复用开篇已解码的首张教程立绘，避免交接时重新下载和同步解码同图；原图字节与画面不变。这只是待诊断验证的候选，尚未修改生产。若实施，必须保留非开篇直接进入教程的资源入口，下载 gate 的 Cancel/失败处理，以及开篇取消、失败回厅、应用停止和重新开篇时的所有权检查；不能用跳过教程或永久保留整个开篇世界代替修复。拿到自然路线失败分配栈和 VFS 差异后再确定最小修改范围。

### 最小对象接管方案（现已实施，验收见上文）

- `CommsPortrait` 提供统一 Nono 源路径查询，指向已与原版逐字节核对的 `Intro/Images/nono_*.png`；其他角色维持现有路径。`Tutorial.Prepare`、`StoryComms.Dependencies` 和卡片图片 fallback 使用同一查询，直接教程入口仍通过原 gate 下载。
- `IntroPage.Close` 在销毁 portrait 前尝试交给 `OpeningHost`；host 校验当前 opening、restore owner、hall、tutorial 身份、未 stopped 和非失败状态。成功才令 page 放弃该对象；未接管仍走原 Dispose，不能两边同时拥有销毁权。
- `CommsCard.AdoptPortrait` 接收整个已暖的 Nono 对象，恢复正常卡片的 330×410 逻辑尺寸及两个 material 的 canvas_size。复用已有 face textures、两个 RT 和同一稳定 VG 的 handles；已有旧 Nono 实例则先按现有 Dispose/retirement 退休。复用对象的 Texture override 只捕获静态 images 路径表，不捕获整页或整场战斗。
- 接管发生在普通 `ReleaseAllResources(false)` 前，Card 的强引用使原图继续存活；不要强制清缓存或 Dispose 被接管的资源。全局 Card 最终由现有 `StoryComms.Shutdown → CommsCard.Dispose` 释放，场景/战斗资源照常退休。
- 独立检查需要覆盖直接教程、成功接管、开篇失败/关闭、应用停止、再次开篇替换旧 Card；证明同一资源对象被使用、不会再同步解码、不重复 Dispose，且取消不会注册过期教程。修改后仍必须自然 Web 复验，不能用离线对象替身关闭 OOM。

自然额外截图现状：`OpeningHost` 只有 charge/wreck 两个 capture 键，截图 Image 在 Texture.SetData 后立即 Dispose；host.Dispose 先删除 NVG video handles，再 Dispose 两张 Texture 并清表。Page.Close 也释放原 imageWarmup、portrait 和漫画 pattern。没有发现确定的 capture 强引用泄漏；这些额外路径只说明自然路线比跳过路线的工作量大，不构成 OOM 根因证明。
