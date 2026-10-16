# 开篇前三格漫画 whoosh

固定源 `b276064942ae09c0227ec28d4cfda1d5ff006455`。只修改生产 `scripts/intro/IntroSession.lua`，没有更改时序、字幕、语音、已有slam、familiar三格或玩法montage音效。

源 `three/src/intro/intro.js` 的 `actVirtues:717` 调用 `cut()`，由384开始的真实方法播放 `whoosh vol=.5`；首格、order、leave又分别通过720/748/756进入 `_panel`，由899播放 `whoosh vol=.6`。原Lua三个阶段只调用Mark、slam与Say，实际少了4次whoosh。

已在prosper循环前补cut `.5`，每个Mark后补panel `.6`，都没有新增Wait。生产冻结SHA256：`84cdbb311c2d568f63c3e3bdd1a0db043e91786223e46a44f7e0a441b1f0a41f`。

新 `tools/migration/source-intro-comic-cues.mjs` 核验基线SHA并实际执行冻结 `actVirtues/cut/_panel/words/voice`，采集调用与受控时钟。`check-intro-comic-cues.py` 实际执行当前Lua `Ad/Mark/Say`，比较4声whoosh、3声slam、原旁白顺序、参数和等待时长。原语音长度、极短、极长3组，183检查、4负控PASS；冻结前生产SHA578326旧版、错误cut音量、错误panel音量、删除panel音效均被拒绝。证据 `evidence/intro-comic-cues-offline.json`，标准报告名 `intro-comic-cues`。

命令：`C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/check-intro-comic-cues.py`。

程序读取共享注册器报告inputs，定位全部8份引用IntroSession的已登记报告，均真实重跑并通过：

| 工具 | 检查 |
|---|---:|
| check-opening-prefetch.py | 184 |
| verify-intro-timing.py | 3989 |
| check-intro-runtime.py | 446 |
| check-intro-gate-offline.py | 920 |
| check-intro-finish.py | 53 |
| verify-intro-mix-transitions.py | 358 |
| verify-intro-voice-clock.py | 330 |
| check-intro-recruit-audio.py | 262 |

本路没有修改注册器/probe，没有运行GPU、浏览器、build或CURRENT。CPU检查通过不代表听感、设备混音或完整开篇实机通过；由root在冻结包统一验证。报告新鲜度中的registry工具自身SHA需待root最后登记后重跑 `check-intro-qa-tools.py`。
