# G4 通讯提示音接续批

接续已有 G4，不重开 G0。基线仍为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，冻结源来自 `.tmp/outgame-source-2026-10-15T12-35-57-243Z`。此增量不包含在此前 e31 构建，须由根线程收入下一统一构建后做试听。

## 实际缺失与修改

冻结源 `shared/ui/nonoComms.js` 的 `_next()` 在通讯卡首次展开或切换说话人时调用 `radio`：诺诺/小运为 `open`，狐狐/董事长为 `intercept`。最后一句自然结束时调用 `close`；同一人连续排队、显式隐藏、外部过场借用 `showSpeaker` 不额外播放。迁移版原先完全缺少这些调用，改前实际 Lua 在 14 场景内有 55 个采样步骤的事件轨迹不同。

- `scripts/audio/StoryComms.lua`：接通原版三个事件，保留原队列、打字、紧急插话和全局通讯卡所有权。
- 新 `scripts/audio/StoryCommsCues.lua`：复用已有 `StoryRadio` 的原批准样本、增益、间隔和音源池；下载通过 `ResourceGate`，解码通过 `BackgroundLoadResource`；只有全部缓存驻留后才构造播放器，不在字幕帧同步解码。
- `scripts/story/Tutorial.lua`：仅在 `Prepare()` 增加八条既有 Radio 资源依赖，已与 G5 所有者协调。
- 关闭通讯系统时取消其专属下载组并显式释放播放器；关闭页面不取消其他资源观察者。

声音未就绪时该次提示音静音，不阻塞字幕、不在后续人物发言时补响。冻结源 `shared/ui/uiSound.js` 的 `voice()` 对缺少已解码 buffer 同样返回 null。首次冷缓存的实际可听情况仍需运行验收；此批不声称完全预热或首句必然可听。

未修改冻结的 `Mission.lua`、`MissionRules.lua`、公共 `UiSound`、引擎库或音频素材。七个复用 WAV 均已与当前冻结 H5 字节及注册 SHA 核对。未新增合成音、未生成素材、未提交或上传。

## 旧 Web 语音解码卡顿接续修复

根线程进一步定位到原 `StoryComms.Preload()` 的兼容分支：资源组下载完成后直接 `cache:GetResource('Sound',path)`，已下载 OGG 仍可能在该帧同步解码，触发首次对白或页面切换卡顿。本批已移除此同步调用。

依据完整 `engine-docs/api/audio.md`、`engine-docs/recipes/download-while-playing.md` 以及 `.emmylua/ResourceCache.d.lua`：现代 `GetResourceAsync` 路径保留；旧 Web 下载完成后先检查已驻留缓存，否则调用 `BackgroundLoadResource`。`StoryComms.Tick()` 每帧最多检查四个解码任务，使用 `GetExistingResource` 接收已就绪的实际声音。已完成下载 gate 及时从活动表移除；`Shutdown` 先解除全局所有权，再取消专属组、停音、释放场景并清空解码/素材引用。后台声音晚到不会恢复已隐藏、过期或换主的对白。

实际回归工具 `verify-story-comms-fallback.py` 将 `cache:GetResource` 设置为直接报错，运行真实 `StoryComms` 与真实 `ResourceGate`：包括旧下载管理器组合路径、现代回调下载接口、现代音频异步接口、9条并行语音、4/4/1逐帧就绪预算、原2秒对白等待超时、隐藏、换主、失败、两阶段Shutdown和重建后晚回调。证据为 `evidence/story-comms-fallback-offline.json`。另已将上节222、结算1392、输入296、教程237按最终SHA重新实跑，全部通过。

这是同步加载调用的修复及生命周期核验，未测真实 OGG 解码耗时、WASM帧时间或可听连续性，不将其记为卡顿全部消失。

## 核验

命令使用项目已配置的 Python 运行时运行 `tools/migration/verify-story-comms-cues.py`：**222 检查通过**。

1. 完整实际冻结 `NonoComms` 与实际 Lua `StoryComms` 比较 14 场景、79 个操作采样：首次展开、两类敌方接入、换人、连续同人、紧急插话、自然关闭、显式隐藏、教程 keepOpen、外部过场和空队列。152 检查通过，事件轨迹差异 0。
2. 实际 `StoryCommsCues`、`StoryRadio`、`ResourceGate`，通过下载/解码/音源适配器检查未就绪、不完整缓存、后台解码、已热缓存、过期回调、两阶段取消、显式释放、焦点和间隔，以及原增益计算。49 检查通过。
3. 实际冻结 `shared/story/radio.js` 映射及七个 H5 WAV 的目标字节/注册 SHA，21 检查通过。

回归已实际重跑：`verify-story-result-quote.py` 1392、`verify-story-input-progress.py` 296、`verify-tutorial-presentation.py` 237，全部通过。后者比原 229 增加八条教程预备资源断言。

证据：`evidence/story-comms-cues-before-offline.json` 保留旧 SHA 的缺失复现；`evidence/story-comms-cues-offline.json` 为当前通过结果。其他三份原报告已刷新到当前生产 SHA。

这些检查没有启动 UrhoX、浏览器或 GPU；没有代签真实试听、音频连续性、自然完整教程/五关、移动端或性能验收。语音原版 DSP/压缩器/噪声、逐段 PCM 连续性仍是既有未关闭项。

## 冻结生产

| 文件 | SHA256 |
| --- | --- |
| `scripts/audio/StoryComms.lua` | `566c1ae47d87d60060b38f323fa6167ae047e19eb3766ac640f66b097a410525` |
| `scripts/audio/StoryCommsCues.lua` | `b138bb0f4c224bffa048fee80a0a71a56808ac3721b3dbd296b660ef624a8a41` |
| `scripts/story/Tutorial.lua` | `393ed127d351955c47b599ae7373a36f5630238dc40434d7eb69f0139bea7011` |

下一步沿当前统一包接入这三个文件，实跑首次教程展开/同人下一句/狐狐切入/自然收尾和离开页面，检查音效是否只响一次、资源未就绪时页面是否持续响应。不得用本报告把整个 G4 标为完成。
