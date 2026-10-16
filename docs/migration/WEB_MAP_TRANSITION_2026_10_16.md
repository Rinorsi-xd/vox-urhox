# Web 重地图切换生命周期

接续 G0-G6 的当前批次。冻结 H5 基线仍为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本批没有提交、推送、改玩法或降低画质。

## 改动

- 新 `scripts/app/WebMapTransition.lua` 只管理当前请求 token、真实呈现帧屏障和恢复状态，不持有或销毁候选场景/物理世界。
- `HangarApp.EnterTrial` 仅在 Web、独立运行、具有 `prepareWorld` 的重地图且当前是有效机库时启用提前释放。PC native、编辑器和普通试车场沿用原先成功后才释放旧机库的流程。
- 加载页由现有 `LoadingFlow.CanStartLoad` 确认真正呈现至少两帧后，解除旧 viewport、挂起 viewport、后处理/tonemap、教程语音、局外 UI、建造、缩略图、目录、换车、车辆、仓库、机库和 scene 的所有权。加载页 overlay 独立存在。
- 再等待三个真实 `pageFrames` 且后台资源载入空闲，调用原有的 GC、`RenderTargetLifetime.Flush`、environment bake cache 清理与非强制 cache sweep。原 `pendingAssetRelease` 的多项回调仍按原顺序执行。资源 gate、纹理暖加载和 `ReadScene` 在此之前不开始。
- 取消/错误由 `SceneLoader.Cancel` 先关闭候选协程并释放 session/world/scene，再排队回机库；下一次 `App.Update` 通过现有 `Reload` 打开 boot 加载页。取消回调内不会重入 `Load`。恢复失败停留在可重试加载页，不自动无限循环，重试重置帧屏障。
- 成功 commit 后，候选 session/world 留给 App；过时 cancel/error/ready 不能替换新世界。停止应用禁用恢复。激活或 loading finish 抛错时清理暂时交给 App 的候选引用和 renderer 持有链。
- 取消后重新装配建造页时不运行初次进入用的 `editor:Lift`，避免改动玩家蓝图。

## 离线验证

执行：

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-web-map-transition.py
```

`114/114 PASS`，实际 Lua 5.4。证据 `evidence/web-map-transition-offline.json` 含生产 SHA。

执行真实 `WebMapTransition`、`HangarApp.EnterTrial/ReleaseMapHangar/DetachSceneRender/DeferAssetRelease/ReleaseSettledAssets/Update/Reload/Stop/PostUpdate` 和 `SceneLoader.Cancel/Fail/Commit`。场景、资源缓存、UI 和 renderer 原生边界使用替身，恢复回调内的 `Install` 也使用替身。覆盖呈现帧而非 update 次数、后台工作阻塞、共享延迟回调顺序、成功新世界存活、覆盖前/后取消、下载/激活/finish 错误、旧回调、实际 Update 排队恢复、真实 Reload 回调与失败重试。独立审查补充实际 Stop 清理候选、重复 Stop、停止后迟到取消、未完成覆盖时抑制 trial PostUpdate、成功覆盖时继续候选预热及停止后禁止更新。

## 尚未验收

- 本文的离线通过不能证明 Web 的第三次入图 OOM 已修复。`CRATER_REENTRY_OOM_2026_10_16.md` 的旧 FAIL 保留。
- 需要同一新不可变包连续三次实际匹配进场/回厅/再来，并记录旧机库释放前后、数组暖加载及 scene 切片的 cache 与实际 WASM heap。
- 需要加载页已释放机库后真实取消，确认重载机库、UI、建造蓝图不变；还需故意失败后真实返回。
- 不签自然战斗整局、视觉、帧率、手机或 M1 验收。`SceneLoader` 去重复 XML DOM 由另一并发任务独立负责，本任务未修改该文件。

## 实际取消回归

- b932b9cd 首轮真实取消失败：释放大厅后没有 UI root，实际 UI.Render 提前返回，加载页全黑、恢复 pageFrames 为0。原证据保留在 `evidence/map-cancel-manifest-b932b9cd-2026-10-15T16-25-26-606Z`，没有交付该包。
- 应用侧窄修在 `Hud.Dispose` 后保留无输入的轻量全屏 Panel；后续真实 HUD 的 SetRoot 替换并释放它。引擎库未修改。实际引擎渲染入口与替换生命周期13项、切场122项离线通过。
- 修复包 `manifest-41e4025e.json` / `.tmp/outgame-cached-1792081852213`，479 Lua，指纹 `6aa95b260594bd840d6aa3a5ded4680c3679d0f449d977e5229ed6026964988a`。
- `evidence/map-cancel-manifest-41e4025e-2026-10-15T16-31-59-783Z`：公开按钮两次进入匹配，旧厅已释放后实际按 Escape，两次完整恢复大厅/模式页。15项 PASS，运行错误0；含真实呈现帧增长、加载页/恢复页非空像素、车辆名/零件数保留、过渡回到 idle。root 已查看加载页和两张恢复截图。
- 仅签实际取消恢复；故意下载失败、三次真正完成进场、OOM、性能和自然整局仍按独立证据判断，不由本15项覆盖。
