# n17 额外底部字幕修复

冻结源：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本增量在不可变82a候选之后，82a自然Web已结束（65功能PASS、连续性FAIL），不能用它的结果签此修复通过。没有构建、GPU、服务、提交或上传。

原 `three/src/intro/intro.js:1250` 调用 `say('n17', {text:'', tail:.3})`，免责声明已在 motto-card 的 m2 层展示。迁移版 Ad 循环仅为n15/n16传空text，n17传nil后Say回退caps.n17，在底部又画了一份字幕。

本单项只改 `scripts/intro/IntroSession.lua` 一行：n17同样显式传空text。原录音、300ms尾部、画面免责声明、所有已批准字幕样式与其他字幕均不改。该单项增量SHA：`01644b56350d564201252052a8797bb72eca35d36b89683a2978805ae4bd6841`；后续集成原后停提示/choiceAt后冻结SHA为 `79ea37589e450cd26873a6470b0792afcba060dff965d24e40f12b763eaf2bd9`，见 INTRO_VOICE_CLOCK 报告。

回归直接执行冻结源实际 actRecruit/say 调用，wrapper只记录显式text参数，继续调用原say；实际Lua从Voice调用时读取已设置caption。12条原时序路线分别校验n15/n16/n17的text，共新增36项。

- 修复前：3989项中12个n17条件全部失败，实际额外字幕为「最终解释权归公司所有。」、源期望为空。原失败保留 `evidence/intro-timing-offline-before.json`，SHA `b1ed6886fc346c3d1bb0f1e9080c4759a111e9ab83de3e657b79f86b61de23c3`。
- 修复后：`verify-intro-timing.py` **3989 PASS**，`evidence/intro-timing-offline.json` SHA `6181f9f57fd95d26f457dc8eaf5b5570a91c3ee79b4a078f9b434fca4ac9d2a8`。报告保留三个源真实text override。
- 集成waitingAdvance/choiceAt后的最终Session再次实跑3989 PASS，当前同名报告SHA为 `69e739e7c91069ec78c6cf04da3dfd6fc4cde14610ad105da5f1a6a00631f1ad`；上条6181为该单项中间报告历史标识，未当作最终集成包结果。
- 后续raw并行下载集成SHA为 `c897536f3dd67695313dcb9a29b795a4a0f257a2e31bb91c92c6ba341019514d`，再次实际3989 PASS；当前报告SHA `3a2e508c6c44b5a001708707edcb0972975fc8bfc90c661d295f8fbd7a419af6`。上条79ea/69e7为上一集成历史，不再是最新生产标识。

这是源码调用与实际Lua状态/时序对照，不是渲染验收；下一统一包检查免责声明无重复底部字幕。其余UI明确缺口由g2独立处理。
