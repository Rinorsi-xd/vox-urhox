# G4 剧情目标与选项自然 Web 验收准备

此文件记录工具准备及下方明确的实际运行结果。实际PC第三关目标/选择窄路线已通过；不是全关卡或手机验收。

## 路线

冻结 H5 `b276064942ae09c0227ec28d4cfda1d5ff006455` 的第三关 `shared/story/level3.js`：出生 `(0,6,-226)`，首目标 gate `(0,5,-200)`、半径 14m。沿初始方向驾驶约 12m 就能进入圈，进入 parley 后等真实开场通讯结束出现 `surrender` 三选一，不需要完整关卡或敌人销毁。

新工具 `tools/migration/check-story-presentation-web.cjs` 从公开「出战→剧情模式→03 围剿→开始任务」进入。PC 只用 W/S 短脉冲与空格手刹接近目标，以现有 F8 probe 只读坐标调整前后；不用传送、改任务进度、直接 Choose 或现有 QA 推关热键。正常按 2 选择、观察半秒确认与退出、正常 T 返回。驾驶限时90s，等待真实对白限时120s；失败保留状态和截图，choice 继续 OPEN。

20:9 `840×378 DPR3` 为真实 mobile UA/touch 浏览器上下文，本工具只验公开首目标呈现和正常返回，不签自然触屏驾驶或选择。PC 也可用 `VOX_STORY_OBJECTIVE_ONLY=1` 只验目标栏。

## 只读观察

QA 独有 `probe-outgame-web.lua` 新增 `story.presentation`：墙钟、现有 objective/choice 的 `sample`、目标 enterAt、choice hideAt，以及最多180帧的 post-update 数组环。数组列名在 `frameFields` 中，避免重复长键挤爆日志。直接读取现有字段，不调用 `State`/`Advance`，不修改生产计时器/规则/位置。离开场景后清空引用。

工具核对最终服务器 manifest（可选 pin）、全部6个相关生产 Lua SHA 和实际 `probeSha256`，保留所有 HTTP >=400；只将该服务器 `game-dist/` 失败作为发布资源断言，其他可选引擎探测单独保留。截图的非空检查不替代人工视觉确认。目标栏初次动画如果没捕捉到中间帧，会明确记录 `ENTRY_NOT_CAPTURED`。

## 待主代理串行运行

```powershell
$env:VOX_QA_BASE='http://127.0.0.1:<新QA端口>'
$env:VOX_EXPECT_MANIFEST='<新manifest名称>'
$env:VOX_QA_CASE='pc'
node tools/migration/check-story-presentation-web.cjs
```

之后切 `VOX_QA_CASE='20x9'` 单独运行。两个 case 不并发开启 GPU。

准备检查：`node --check` 通过；probe Lua5.4 load通过；隔离执行实际帧环代码验证200次采样限制180、首项顺序21、choice字段不修改与退出释放通过。尚未取得真实 Web 结果，不签 G4 关闭。

## 实际 PC 运行

root 已在 `manifest-5b8cf21c.json` / QA4406 完成公开第三关入口、真实W短驶触发gate、等待原对白、按2选择、确认选项停留与退场、正常T回厅。证据 `evidence/story-presentation-manifest-5b8cf21c-2026-10-16T01-14-34-240Z/`；15检查PASS、运行错误0、HTTP失败0，进程结束0。

实际采到了目标进入的中间帧、surrender三选一、第二项500ms确认与退出；root查看了选择界面截图。不使用传送、改进度、跳语音或直接Choose。本次没有完成第三关防守/胜利，也没有执行20:9自然驾驶或全剧情演出验收。

进场仍慢，不能因功能PASS签性能：加载页实际记录download34.938s、resources1.478s、scene6.223s、prepare7.071s、activate36.687s。预热逐段归因另行核查，不能把36.687s总时长当成单次冻结或宣称加载已优化完成。
