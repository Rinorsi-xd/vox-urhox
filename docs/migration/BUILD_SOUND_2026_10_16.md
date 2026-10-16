# 原版建造操作音效接线

继续当前G2/G4/G5接续位置，不重开G0。冻结H5分支 `2026-10-15`、提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`。本增量在e31之后，尚待下一统一包实际Web操作和试听，未提交、上传。

## 原始资源与规则

全部复用冻结源中已批准的Mivo原WAV，不重新生成。`import-ui-sounds.mjs`依据原 `WORKSHOP_CUES`、`HANGAR_CUES`、`MIX_TRIM` 导出七cue，共151126字节；相对e31增加92856字节。原字节、gain和gap均由源实际模块逐项核对。

| cue | gain | 最小间隔ms | 原样本来源 |
| --- | ---: | ---: | --- |
| press | 0.10 | 85 | ui-click-r2/press_a.wav |
| open | 0.32 | 120 | workshop-01/open_a.wav |
| place | 0.20 | 65 | build-soft-r2/place_b.wav |
| remove | 0.16 | 65 | build-soft-r2/remove_b.wav |
| paint | 0.28 | 60 | workshop-01/paint_a.wav |
| confirm | 0.24 | 100 | hangar-02/confirm_b.wav |
| stamp | 0.44 | 150 | hangar-02/stamp_a.wav |

UiSound复用后台准备和现有AudioLevels；实际gain为上表乘原主音量0.65，再按当前sfx设置缩放。Play不下载、不调用GetResource、不解码；未就绪跳过。声音池改为源全局上限10，同cue最多3。hover保持原disabled静音。

## 成功操作接线

- `BuildEditor`实际放置、拆除、改变涂装颜色、批量粘贴、选中组合并、转轴模式成功提交后分别发原cue。无命中、无效、同色、错误工具、同转轴模式及空提交无声。
- `BuildStretch`只在最终成功提交发place；开始、矩形/高度预览、右键回退及取消无声。
- `LiverySession`实际贴上贴纸发paint，实际选中删除发remove；上限、未选择、取消不发声。镜像、复制、移动、清空、撤销和重做沿原版保持无独立cue。
- `InventoryPanel.Open`首次实际打开库发open；重复Open和响应式restore重建无声。
- `BuildSession.SaveSlot`、`BlueprintLibrary`的真实保存成功才发stamp。空位/覆盖成功均覆盖；覆盖确认尚未答复、失败、打开库和取消不发stamp。底层Garage自动保存不增加声音。

建造域通过可选 `onCue` callback输出语义，BuildEditor/BuildStretch/LiverySession没有新增audio/UI运行时依赖。HangarApp创建editor时、LiveryPage创建session时分别注入 `UiSound.Play`；不提供adapter时静音，仍可独立加载域模型。

## 验证与身份

- `check-build-sounds.py`：**124 PASS**。执行冻结源实际Editor/Blueprint的21案例、真实异步save的3分支、Inventory.toggle的5状态和Livery的6案例，对实际Lua Blueprint/History/Editor/Stretch/Session及实际保存按钮callback比较。包含实际蓝图数量、撤销重做静音、无声音adapter不依赖UiSound、响应式恢复不重复开库声。UI原生对象、渲染、存储设备和声音设备为边界适配。
- `check-ui-sounds.py`：**180 PASS**。七原WAV字节/gain/gap、原按钮5条件、教程4手动/5自动条件、异步未就绪不阻塞、七cue重叠总10/单cue3、每条间隔/音量、焦点/最小化和Dispose重开。
- `verify-tutorial-presentation.py`：**237 PASS**，包含并发通讯资源准备增量，Tutorial最终 `393ed127d351955c47b599ae7373a36f5630238dc40434d7eb69f0139bea7011`。
- 独立审计agent按最终HangarApp重跑竞技结果13005项及竞技动作103项PASS，全部43报告216SHA无漂移；scoped diffcheck PASS（仅既有LF/CRLF提示）。

完整资源和生产SHA由 `evidence/build-sounds-offline.json`、`evidence/ui-sounds-offline.json` 原工具自动计算，未手改报告。关键生产SHA：

| 文件 | SHA256 |
| --- | --- |
| scripts/audio/UiSound.lua | 373a5913aeee6bc9e1a3ed4f8b135558b2254607d3e2b3cd731508f79c2b1f87 |
| scripts/construction/BuildEditor.lua | 9ea7081380dfc1470f1f434ff3193541fe07a570835a759808681e4d191d4206 |
| scripts/construction/BuildStretch.lua | ebacd0c9398662bce30fb8b6169631dd66c86c46766350c52dca2a1a5c59bdba |
| scripts/construction/LiverySession.lua | 103a1c41ef3800200e9277707d04db70c2ad4c6ae25c9dc279346e277b7f4a40 |
| scripts/app/HangarApp.lua | 9be8a942a155812651bdacbdd23699d46a4de7d63953349894472dbe094c8487 |
| scripts/ui/LiveryPage.lua | f839f49c76a4345c0c5b92ae20cd0515f00e1c5e4eced9cd3c62445cb6dab31d |
| scripts/ui/InventoryPanel.lua | 7c04705602e8ef04708dd40c6fcb210d5b2fa1f96e44263af025b7b8698841c9 |
| scripts/app/BuildSession.lua | 85b5a5e4d370d7f39e6f11417098871fcf44cff823280328fef9c69a5b925b28 |
| scripts/ui/BlueprintLibrary.lua | 3a2408531539ad8a7a826ef438571d1ec4d7a8805c2d9da87253d027bd3fe6a4 |
| assets/UI/Sounds.json | 4de538de0df0bd7cc58bce7f4737dee988f2207531fdf46dbc8b643ae38e264b |

首轮适配夹具缺InventoryList/MaterialHeader，已补窄UI边界；callback解耦时Stretch一处错误变量被真实Lua检查发现并修正为editor，随后124项全通过。没有以生产放行为方式绕过断言。

## 未关闭

下一统一包真实建造操作/试听、完整PC和横屏触摸输入仍待root验收；本离线检查不签视觉1:1、音频不卡顿或真机帧率。源 `Editor.paintSelection` 的独立选择批量涂色入口尚未在目标找到对应方法，保留为G2建造缺项，本批未为补声另行设计玩法。矩形/选择拉伸的全源计划对照不在声音检查范围，成功声不等于拉伸完整验收。e31此前真实普通按钮/教程证据不能代签本批新操作。
# Follow-Up: Actual Web Button Recognition

The c787 frozen package failed actual primary-button audio in two Web runs: right/middle correctly stayed in the hangar, but primary deploy navigated without a press cue. Reports `combat-performance-2026-10-15T18-47-44-337Z` and `combat-performance-2026-10-15T18-51-18-307Z` retain this failure. Neither run reached a match.

The second run's read-only trace found a focused, non-minimized primary pointer with all seven cues ready. `Widget:new` wraps each instance in a property-routing metatable; the old detector treated that wrapper as the class, so its superclass lookup stopped. `UiSound` now follows the exposed superclass chain from the instance. The offline check now constructs actual engine `Widget:new` instances, including direct Button and two descendant levels, disabled controls and a non-button. There are 200 passing checks; the corrected package still needs real public-pointer confirmation. These changes are newer than c787.

