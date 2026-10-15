# 竞技罗盘与小地图增量

接续 CURRENT_EXECUTION.md，不重开 G0。本批生产已冻结，真实 Web 验收由 root 的统一包负责。

## 源依据与修复

- 当前活动源为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`；源 `shared/ui/matchHud.js` 和 `three/src/battle/matchView.js`。
- 顶部多余的 `000` 是竞技罗盘遗漏源 `translateY(100px * --mh-ui)`。`ReticleGauges.Compass` 仅竞技对局增加源位移，保留罗盘及导航内容。
- 小地图离屏 NanoVG 的 hole 和凹箭头填充没有有效 stencil：实际 RT 曾清掉底色并把箭头画为白矩形。箭头改为组成同一轮廓的两个凸三角；圆/切角方形裁剪用冻结源 Canvas 路径生成固定 alpha mask，整张矩形 `DESTINATION_IN` 一次合成，保留源抗锯齿。不再使用 192 个超大半平面。
- 两张技术遮罩为 `UI/Match/minimap-mask-round.png`、`minimap-mask-square.png`，已列入 `BattleController.Dependencies`，每个私有 VG 创建一次并销毁 image。
- `MatchMapShot` 拍现有场景，不复制世界。正交640米、相机高1200米、1024平方 RT，连续5个实际RT视图完成后等待3帧再读回。保留源3%/98%亮度分位和冷灰蓝调色，以4ms协程预算分帧处理。
- 当前 pinned runtime 中新文档的 `depthFog*` 字段可静默赋值但不影响旧雾参数；实际隔离显示只改新字段1200米黑图，兼容旧 `fogStart/fogEnd/fogDensity/heightFog` 后恢复画面。捕获视图的 `BeginViewUpdate` 暂存并关闭 scene/default Zone 雾，`EndViewRender` 和取消准确恢复，包含 nil 字段。
- 陨坑实例群组的 `drawDistance=150/220` 会被1200米俯视相机裁掉。捕获视图仅临时将 Octree 返回的 `OctreeQueryResult.drawable` 非零距离设0，视图完成后恢复。未改阴影距离。
- `TrialSession` 在原 SceneLoader 加载页完成捕获和调色，进度覆盖 `.96..999`，正常 Take 交给 `MatchMinimap`；取消释放仍归部分 session 的 Dispose。没有 checkpoint 的专用夹具仍可后台更新。
- `MatchMinimap.base={image=VGhandle,texture=Texture2D,half=320}`。接收方拥有 processed texture，替换或 Dispose 时先删 VG video 再释放 texture。

## 已执行验收

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 实际 Lua 罗盘4比例、触屏/PC、竞技/非竞技 | 32/32 PASS | `evidence/compass-match-offset-offline.json` |
| 实际 Lua HUD/目标/小地图 | 19904/19904 PASS，80源夹具 | `evidence/match-hud-detail-offline.json` |
| 原生 RT 默认顺序/显式顺序/切角方形像素 | 27/27 PASS，Lua/resource0，最大85.110ms | `evidence/minimap-render-20261015T131006063.json` |
| 原生4块地图实际捕获，源方向/冷灰调，scene/default fog和150米距离恢复，释放/取消 | 33/33功能PASS，Lua/resource0；总体性能FAIL，保存图帧110.197ms | `evidence/minimap-render-20261015T131237573.json` |

已打开并查看 `evidence/minimap-mapshot-base.png` 和 `minimap-mapshot-screen.png`，有实际四块地图布局；不是均匀纯蓝。源分位调色会让不足2%面积的最亮块和次亮块同时饱和，最终夹具白块面积超过2%再比较三级亮度，未改生产调色。

旧失败记录保留：黑图、使用不存在 RenderPaths/Forward.xml、hole/凹箭头白矩形、错误将 OctreeQueryResult 当 Drawable 的 nil 错误，以及无效 tolua.cast 导致超时。最终生产无该强转，使用文档明确的 `.drawable`。

## 冻结 SHA256

| 文件 | SHA256 |
| --- | --- |
| `scripts/render/MatchMapShot.lua` | `c218a41dd252c3b2267a2d98d573d930c70511524f323b71b0aea7622b66f1ba` |
| `scripts/ui/MatchMinimap.lua` | `42e75518c6c34ba222b076e03b89c70eea31de3d21631439c1650f66b24a4baa` |
| `scripts/ui/ReticleGauges.lua` | `62071a64c716193c931c2e0e8479d6346037894260e161b785c8178b43c7cbb4` |
| `scripts/app/TrialSession.lua` | `5447e7429c56cac14dcf0a9be5d7dd54497336aa63eaa6c61f953a1e4ae2badd` |
| `scripts/combat/BattleController.lua` | `3e594168a29f34adaa0207277c57950b1e841edcf26becd4ad845b7219f9c0bb` |
| round mask | `90362373120554fdbf10c1765b39561929f685b23248c8f372e15b9f8d3c4cd0` |
| square mask | `727f3540236bfcdbc7da9a760617b0197c83db5eca3c5dea87f202f6ae24c32f` |

## 待验边界

- root 新统一包实际 PC/20:9 公开匹配入口、地图纹理桥接方向、顶部计分板/罗盘避让。
- 上述原生捕获增加约4至5秒分帧处理，已在加载页内；不宣称缩短总加载或移动端达标。
- 4块场景夹具不替代真实陨坑完整地图的最终目视检查，也不签真机性能或1:1整体完成。

## Web 新阻塞与候选续修

`3a0f7886` 真实 Web 进场在 `prepare/minimap` 不推进，最终超时，原生功能通过不能覆盖此失败。root 的独立事件计数确认 `BeginViewUpdate/EndViewRender` 各67次，Camera/Texture均67次精确相等，但生产 `views=nil/captured=false`，排除RT不渲染及指针过滤不匹配。

候选处理：不再等到 SceneLoader 协程首次 `New` 才注册全局渲染事件，`scripts/main.lua Start` 主线程、Storage.Boot之前显式调用 `MapShot.Initialize()`；Stop先释放app再调用 `MapShot.Shutdown()` 释放active、退订和重置初始化标记。New保留幂等初始化支持专用夹具。文档没有承诺协程中的全局事件注册语义，这一根因解释仍需Web新候选证实；QA移除同事件订阅避免诊断干扰，仅保留只读状态。

此候选冻结：`main.lua a9737c4f70c1b480351fb5e978bd3e24b5c51305316c5735562ebef246c1ed44`；`MatchMapShot.lua 60c6a345e067846b45f05f911b607375beb11a3e5f9f30542608e65e730b8b9c`。上表C218为此前原生已测生产，不能将其33/33原生或旧Web结果改挂此候选。

## 实际 Web PC 专项复核

root 的主线程初始化新包已实际进入公开匹配，解除此前 `prepare/minimap` 不推进；随后 `9e05` 实图发现Web多余上下翻转，N和箭头倒置，以及底图全RT矩形采样造成边界延展。这两处失败保留，不能拿状态断言代替画面验收。

root 窄改后 `04a` 统一包，生产 `MatchMinimap.lua` SHA256 为 `862542d0d6c2bbd777fc146768a2ab54deb6e1969bbe1e8ad6b8245f6da35c5e`。删除Web额外翻转，底图只绘制源 `drawImage` 对应的投影矩形；仅无底图时使用fallback，底图范围外保留源透明与边缘暗化。

PC证据 `evidence/combat-performance-2026-10-15T13-32-02-582Z/`，脚本指纹 `ee0e9dfe08f03dc62cacfd80f40386a546386e4ee0ccfe7d114393bf01a90af6`。实际入口/HUD状态5/5通过，运行错误0。root和g5分别打开 `match-hud.png` 与 `match-minimap.png` 独立目视确认：N在顶部，白/蓝箭头向上且没有白矩形，底图有建筑、道路与散布碎石，没有边界延展条纹；顶部计分板和罗盘000已分开。

这里只签PC本次截图和专项状态。20:9触屏正在root独占实测；不签全部UI字体1:1、整场战斗、加载/持续性能或移动真机。上述33项原生证据仍属于原C218版本，不改挂04a。
