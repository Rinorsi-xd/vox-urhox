# 局外切页与错误提示漏音

本批继续固定 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，没有重开 G0。恢复两个确证漏迁的 cue 与公开入口，不扩大转场或首次进出流程。

## 原版依据与生产结果

冻结 `shared/audio/hangarCues.js`：whoosh 使用 b、gain .24、gap 120 ms；error 使用 a、gain .25、gap 150 ms。冻结 `shared/ui/shell.js` 的 tab/salvageTab 在非 quiet 时播放 whoosh，包括同页再次选择；`shared/ui/ui.js` 的 toast 只在 kind=bad 时播放 error。

- `assets/UI/Sounds.json` 从 7 cue 补到 9 cue；复制原 WAV，不生成替代声音。whoosh_b 51,586 字节、error_a 45,946 字节，总新增 97,532 字节；源字节与 SHA 均由 checker 验证。
- `GarageHud.SetTab` 和 `SalvagePage.Tab` 支持可选 `{quiet=true}`，公开调用按冻结源播放 whoosh；HomeView 本身没有加音。
- `SourceToasts.Push` 仅有效 bad 提示播放 error，空内容、已销毁、info/ok/warn 不播放。
- GarageHud 创建车辆的内部主页面刷新，以及 SalvageBuy 在公开 garage tab 后的外壳刷新设 quiet，避免重复音。普通车位切换不新增 cue。
- UiSound.lua 与 AudioLevels.lua 混音不变。导出 gain 已包含一次 MIX_TRIM；whoosh/error 无额外 trim。已有 UiSound 的 .65 与 AudioLevels 的 sample master 沿用原 shared uiSound 的两层总线关系，不再乘第二次 trim。

## 运行检查与失败记录

`evidence/hangar-cue-hooks-offline.json` 是新增标准报告：实际执行 GarageHud.Create 安装的 SetTab、完整 SalvagePage.Tab、SourceToasts.Push，对照冻结 JS 的 8 个 tab 情况与 4 个 toast 情况；38 项通过，缺主页 whoosh、忽略 salvage quiet、warn 误响 error 三个负控均被拒绝。Widget、设备与场景边界为适配器，不是浏览器听感验收。

实际重跑既有报告：ui-sounds 218、build-sounds 124、g5-extraction 547、action-buttons 1353、game-audio-context 851、button-keyboard 99、loading-root-lifecycle 13、story-page-lifecycle 126、workshop-shop 450、garage-acquire-entry 9，均 PASS。workshop 新增真实购买成功后的 quiet 参数断言，并把实际运行的 SalvageBuy 纳入输入哈希。

首次 story-page-lifecycle 重跑 FAIL：夹具写死 `s.SetTab=function(tab)`，未找到新增 options 后的签名。已修定位串，并在该只验 UI 退役的夹具上加入 UiSound.Play 设备适配器；真实重跑 reference 与缓存 runtime 两模型 126 项及历史/变异负控均通过，没有借修改夹具屏蔽生产 UI 生命周期错误。

首次购买与公开 cue 组合夹具均执行真实 Lua，新增 WAV 的原字节由 frozen source registry 对照。无 GPU、native 启动、构建、提交或上传。本批不签真实音量听感、声音卡顿、手机或全游戏音频完成。

## 冻结生产身份

| 文件 | SHA256 |
| --- | --- |
| scripts/ui/GarageHud.lua | 0f525ae3d974beaac44ee1afde33ed2de64aad2e83963e883fd82f900c06a624 |
| scripts/ui/SalvagePage.lua | 7dbf9cc2101598ff4dd27f96487df66164b147f9b315fa800fd52a20602dcaae |
| scripts/ui/SourceToasts.lua | d3300da19712bdb7afdd585dd4582a283a5833b511070f20c45e14c14efac1a6 |
| scripts/ui/SalvageBuy.lua | 340ee6e07dd10e5df808778c834d27e6e5e0855198d95eaac40fdb7817b3341a |
| assets/UI/Sounds.json | 320f00dfa48407d643384b0d54bffbe069cd5509333d90cb9cff83fb4bbb15d0 |
| assets/Sounds/UI/whoosh_b.wav | 7b4d0138807fda2c728600822b80813ad555ba94291e551ea3229dec0b95904c |
| assets/Sounds/UI/error_a.wav | 2439690f721da08063c12bc93f35d6d2a3915a78406fbd8a09dd01f6242895aa |

源源码 SHA、生产哈希与测试输入映射在 `hangar-cue-hooks-offline.json`、`ui-sounds-offline.json` 中。新 cue 通过现有 UiSound.Dependencies 的下载/后台准备链载入；首次进入缺字节或未完成解码时仍跳过，不在点击回调同步解码。

## 仍待下一批

本包按 root 要求不扩 HangarApp/BuildSession。冻结源 Shell.go 中从编辑返回 home、非编辑进入 salvage 的 whoosh，与转场 cover/reveal 的漏音仍需独立对照并接线，不能把本报告称为完整进出声已迁移。新包还需 root 串行实测公开主页/打捞页切换、bad 提示、音量设置/失焦及听感。
