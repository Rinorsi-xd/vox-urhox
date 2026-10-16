# 大厅音乐异步资源准备

接续 `CURRENT_EXECUTION.md` 的 14f 交接冻结，不重开 G0。冻结 H5 仍为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。

## 本批生产改动

仅 `scripts/audio/MusicPlayer.lua`，SHA256 `1914a500636eb48aa7451e0d61403aa5cfa9fc51505171ec81adab7acb980b58`。不改 OpeningHost、IntroSession、音乐库或曲目资源。

- 原 Next/Choose 位置不动；不预选首曲、不预缓存整个库。
- 下载完成回调只写就绪或错误，不再在下载管理器回调中同步 GetResource、构造播放源或写存档。
- Update 使用 GetExistingResource；缺少时只发一次 BackgroundLoadResource，后续每帧只轮询这一个 pending Sound。资源就绪且 CanPlay 后执行原 Play、2.4 秒渐变、Played/Save。
- 暂停、隐藏、未解锁、静音或禁用时允许准备，但不提交新播放、不推进音乐时钟或播放历史。原 current/fading 双槽和切组、Clear、Dispose token 失效保留。
- 无可用 Sound 时最多等待 20 秒可播放时间后进入原失败/重试流程。后台请求返回 false 可能是其他观察者已经排队，继续轮询，不立即误判失败。暂停时间不计入该超时。

## 已执行验证

`tools/migration/verify-music-preparation.py` 执行实际新 MusicPlayer、实际 AudioLevels 与实际 ResourceGate，另加载 SHA 已锁定的 14f MusicPlayer 做旧行为对照。`evidence/music-preparation-offline.json`：554 项 PASS。

12 首实际 shuffle 选择和穿插的共享 math.random 结果与旧包相同，渐变中点/终点相同；旧模块 12 次同步 GetResource，新模块 0 次，新路径同步调用设为直接抛错。还覆盖暂停/隐藏/锁定/静音/禁用就绪、快速手选、切组、续播、迟到回调、无效音频、共享后台队列、异常/超时/重试、原单曲循环/seek/previous、两槽播放源和 Dispose、旧版 DownloadManager。

测试替换了原生场景/文件解码边界，不是 MP3 解码、听感、Web 帧率或移动端验收。后台 MP3 的最终装载和首次 Play 仍可能有主线程费用；尚无新包性能结论，不能将旧 14f 的冻结消除或连续性通过挂在本批。

## 新包必须重跑

- 完整自然开篇回厅，分段计时释放与音频准备/播放，检查 RAF、音频回调及教程交接，不能复用 14f 证据。
- 音乐盒实际选择/暂停/切曲/关闭续播和两槽资源释放，原 Web 工具已等待实际 duration/track，可用于新包。
- native `check-music-box.lua` 已改为等待实际 Track/Position 就绪后执行原暂停、seek、收藏、关闭续播检查，人工 backend 使用 GetExistingResource/BackgroundLoadResource，且断言下载回调本身不提交播放。验证窗口改为最多 1250 帧，仍受原 80 秒截止限制；尚未运行新的原生验收，旧 PASS 不适用于本批。
- 原音量设置/音频等级与生命周期回归，原生或 Web 的未执行项保留 OPEN。

本批未启动 GPU、服务、构建、提交或上传。开篇声音的触发、低通、峰值压缩、时机与完整演出另行逐项对照，不因本项通过而标为完成。
