# 声音设置面板音乐试听音量修正

冻结 H5：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。

源 `shared/audio/gameMusic.js` 的实际 `GameMusic.tick()` 将声音面板从普通模态压低音乐的条件中排除：`modalOpen: this.ui.modalOpen && !audioPanel`。迁移版此前把任何 `home.dialog` / `session.dialog` 都作为普通模态，因此在大厅打开声音设置时额外压到 0.5，关闭又恢复；试听设置会产生误导。

仅修改两个生产文件：`AudioSettings.Open()` 为实际创建的面板写入明确身份 `sourceAudioSettings=true`；`GameMusicState.FromApp()` 排除这个面板的额外模态压低。驾驶指针解锁、局内改装暂停、其他模态、提示音、语音和原有 duck 取最小值规则保持有效。

`check-audio-panel-duck.py` 执行冻结原版真实 `GameMusic.tick()`，并实际执行 Lua `AudioSettings.Open()` 创建面板，再送进真实 `GameMusicState.FromApp()`；外部 UI/cache/音频接口使用 CPU 适配器。九组源代码情况和八组真实 `FromApp` 空状态回归，共 70 项断言 PASS；旧无条件模态压低与错误的仅排 nil 守卫两项负对照均被拒绝。

| 情况 | 与原版一致的 duck |
|---|---:|
| 大厅正常 / 声音面板 / 关闭声音面板 | 1 |
| 大厅其他模态 | .5 |
| 驾驶声音面板，指针仍锁定 | 1 |
| 驾驶声音面板，指针已解锁 | .5 |
| 局内改装暂停的声音面板 | .5 |
| 声音面板期间反馈音正在播放 | .45 |
| 声音面板期间通讯语音正在播放 | .5 |

受影响原有检查均实际重新执行：`verify-game-audio-context.py` 851 项 PASS；`check-match-mvp-audio.py` 611 项 PASS；`check-endless-audio.py` 160 项 PASS。报告分别为 `evidence/audio-panel-duck-offline.json`、`evidence/game-audio-context-offline.json`、`evidence/match-mvp-audio-offline.json`、`evidence/endless-audio-offline.json`。

生产冻结 SHA256：

| 文件 | SHA256 |
|---|---|
| `scripts/ui/AudioSettings.lua` | `7c241afdfba2e79edc4224c24e0b400e118e7f08e975187adf1c9bd2063e3f09` |
| `scripts/audio/GameMusicState.lua` | `a379fc933daa3ec94a928ba5e5103de6c48d92c4e894c9eb74ce0fefcb31ecda` |

这只验证路由和包络参数，不证明原生音量输出、听感、实际交互或 Web/GPU 验收。未启动 GPU、未构建、未提交、未上传；主线程合入新构建后再做实际试听。

## EDD 实际 Web 失败与修复

主线程新构建 `manifest-edd94237.json` 的驾驶 Web 验证在大厅冷启动报错：`audio/GameMusicState:34 attempt to index a boolean value (local 'dialog')`。证据保留为 `evidence/driving-audio-web-pc-manifest-edd94237-driving-loops.json` 及对应日志，真实浏览器已关闭；该构建未交用户，不能将先前 CPU 46 项通过当作完整启动通过。

根因是本轮面板候选使用 `dialog~=nil` 后读取字段，而已有 UI 使用 `false` 表示尚未创建或已关闭。现在在字段索引前使用 `type(dialog)=='table'`。新增实际 `FromApp` 调用覆盖 home 为 nil/false、dialog 为 nil/false/true、大厅 trial=false、trial 模式 session=false/nil；这些状态必须返回 hangar / duck=1 / paused=false。将守卫恢复成旧候选 `dialog~=nil` 的负对照在真实 false 状态下抛错，检查必须拒绝它。

修复后的 70 / 851 / 611 / 160 项 CPU 检查均实际重新执行通过。上述 SHA 和 `audio-panel-duck-offline.json` 已更新到修复后版本，`testInputs` 保留完整工具路径与实际 SHA。本子任务没有再启动 GPU；修复后新的统一构建与 Web 冷启动复测由主线程负责，EDD 的 FAIL 不覆盖、不升级成通过。
