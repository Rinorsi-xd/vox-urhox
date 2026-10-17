# Crater 单张烘焙贴图 2048 隔离 A/B

日期：2026-10-17。状态：两次实际 Web 进图均 PASS；root 对照两次出生视角截图未见明显差异，已将候选合入工作区和 `manifest-c881928c`。近景图集细节及移动端性能仍未验收。

## 结论

将 `Crater/texture-2.png` 从 4096 缩至 2048，明显缩短了这份资源的主线程下载完成回调：**3780.183 -> 875.256 ms**，单次降低约 **76.85%**。整次进入陨坑仅 **68537 -> 65617 ms**，减少 2920 ms，约 4.26%。这不能解决仍约 28 秒的场景及战斗 shader 预热。

本轮每个条件只有一次，且同时开启 Chrome trace、CPU 采样、开发日志及 QA 观察。所有耗时只用于本次相同观察方式下定位，不能作为正常 FPS、骁龙 845 或 TapTap 持续性能结果。

## 构建与实际消费证据

| 条件 | A | B |
| --- | --- | --- |
| 本地端口 | 4505 | 4507 |
| manifest | `051eb631` | `1c389cf7` |
| 证据目录 | `evidence/debug-settings-1792177548599/` | `evidence/debug-settings-1792177706503/` |
| 目标纹理 payload CRC | `ede8272b` | `ef454d81` |
| PNG 文件字节 | 21,561,575 | 4,906,546 |
| trace ResourceFinish decodedBodyLength | 21,561,575 | 4,906,546 |
| 运行结果 | 实际 crater、无 Runtime/HTTP 错误 | 实际 crater、无 Runtime/HTTP 错误 |

B 的 trace 实际请求 `Hfv3EZCdYOjVwwaWmqanHMaa-ef454d81.png`，并收到与候选相符的字节数，不是复用旧纹理 URL。派生包检查确认 543 个 Lua 哈希完全一致，manifest 仅变更这一个资源；材质、贴图 sidecar、UV、物理和其他资源不变。候选为 Pillow BOX 精确 2x2 面积平均，RGBA8，B=0、A=255，无 gamma 转换。

原冻结 identity SHA-256：`1ba29e172d48d1f3c035a0456403bc008c72afe2b3c25c769ba9830346acffdb`；原 manifest SHA-256：`a1b256e1e4ef635fa38649ef596784310a0d1463c2dadc5130279288d3579cc3`，派生后复核未变。B 的 `assetDerivative.status=DERIVED_NOT_RUN` 是派生时保留的构建元数据；本次实际运行状态以 B 的 `result.json=PASS` 为准。

## 原始耗时

单位 ms。XHRLoad 是主线程收到数据后的完成事件回调，不是网络传输时间。表中 XHRLoad/RAF 各自统计原始 X 事件，不再叠加其嵌套 FunctionCall。

| 项目 | A | B |
| --- | ---: | ---: |
| 目标纹理 XHRLoad wall | 3780.183 | 875.256 |
| 目标纹理 XHRLoad thread CPU | 3701.014 | 857.304 |
| 全部 387 个 XHRLoad wall 合计 | 25300.884 | 23142.214 |
| 最大 RAF wall | 1988.594 | 2015.539 |
| getProgramParameter 叶样本时间 | 11776.872 | 11989.423 |
| getShaderParameter 叶样本时间 | 245.313 | 256.359 |
| MinorGC wall 合计 / 最大 | 69.654 / 0.823 | 64.440 / 0.901 |
| MajorGC wall 合计 / 最大 | 3.924 / 3.924 | 10.825 / 6.791 |
| 父测试入口到加载完成 wall | 68537 | 65617 |

LoadingFlow 阶段边界的 elapsed 是墙钟时间，可能包含资源回调、引擎处理及观察成本，不等同于标签所指操作的纯 CPU 时间。

| LoadingFlow 阶段 | A | B |
| --- | ---: | ---: |
| download | 27024 | 24741 |
| resources | 1538 | 1548 |
| scene | 5924 | 5037 |
| prepare | 3294 | 3249 |
| environment | 0 | 0 |
| activate | 28781 | 29044 |
| 阶段合计 | 66561 | 63619 |
| scene warm-up（activate 内，不能再与其相加） | 15996 | 15942 |
| combat warm-up（activate 内） | 11532 | 11798 |

## 长任务 owner 与不确定性

1. **资源完成回调链**：A 最大任务正是目标 PNG 的 onload；两个未变的岩石模型也有 1729.947、1459.028 ms 回调，B 为 1756.958、1391.307 ms。CPU 样本大量落在 `xhr.onload -> reportSuccess -> doCallback -> WASM -> _emscripten_get_now/now`。缺 WASM 符号，目前不能将其进一步断言为 PNG 解码、磁盘写入、锁等待或计时器本身的成本。
2. **GL program 首次同步检查**：A 最长 RAF 中约 888.950 ms 样本落在 `getProgramParameter`，两组总样本均约 12 秒。runtime 有 436 / 437 条 shader compile 成功日志（包含机库），符合首次生成/编译及状态检查造成预热长任务。GL 调用的样本墙钟可能包含驱动等待，不是 GPU 执行时间。
3. **浏览器 GC**：已记录的 V8 GC 很短，不能解释数秒级冻结；这不等于排除了未独立计量的 Lua GC 或 WASM 内存管理。
4. **WASM 编译**：trace 没有能归因本轮长任务的 WASM 编译事件。出现无符号 wasm-function 只证明执行了引擎代码，不能称作 WASM 编译卡顿。

候选节省的未压缩单 mip RGBA 理论量是 48 MiB；现有 `texture2DBytes=0` 等计数没有提供可信的目标 GPU 实际显存，不能据此宣称实测节省 48 MiB。材质使用、实际画面清晰度、图集渗色和远处画质仍需单独验收。随机背景音乐不同，也会影响整次加载的少量时间和缓存统计。

建议下一步向引擎侧提供两份 trace、cpuprofile 和 runtime.log，针对资源完成回调的无符号计时链及 GL program 状态查询做符号化；本次合入的贴图缩减不能当作已解决全部加载或对战卡顿。原 4096 资源仍保存在冻结 A 包中，可从该单一资源恢复，无需恢复其他工作区文件。
