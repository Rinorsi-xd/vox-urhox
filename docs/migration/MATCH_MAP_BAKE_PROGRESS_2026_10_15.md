# 陨坑小地图离线烘焙与运行时回退

## 当前冻结点

- 继续既有 G3/G6 加载优化，不重开 G0。
- 对齐源分支 `2026-10-15`，提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`，源内容 SHA256 `edd9d0de1b29843c739f0dfd13eb0086977d6f3b1422954f5c8cf31085232d68`。
- 生产改动仅 `scripts/render/MatchMapShot.lua` 及 `TrialSession` 传入现有地图配置的一行；不改小地图坐标、绘制、战斗或 main 事件注册。
- `MatchMapShot.lua` SHA256 `b9496df58ae801eedbe877c90075a4927e361d17cefc1b9848a82489ff2b7762`。
- 本文记录工作区增量；04a23389 包及其 PC/20:9 验收属于烘焙接入前，不能签本次 Web 已通过。

## 交付与生成命令

```powershell
powershell -ExecutionPolicy Bypass -File tools/migration/bake-match-map.ps1
node tools/migration/bake-match-map.cjs check
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/bake-match-map-check.py
```

- 生成 `assets/Crater/Minimap.bin`：实际 PNG 无损字节，2,025,492 字节；使用 `.bin` 保持发布端不将 CPU 可读图自动改成 ASTC。
- 生成 `assets/Crater/Minimap.json`：208,968 字节，记录源基线、1145 项资源/脚本/引擎构建输入、SHA256、字节数、引擎 checksum、生成配置和证据路径。
- 构建前必须执行 `check`；源基线、地图输入或像素文件改变时拒绝旧产物，重新烘焙。当前构建脚本接入由 root 统一处理。
- 当前 input SHA256 `6b541444298124ec7e46fe8d7ec0e93b5e558ba8496adb7bd7a2b199ea17f305`。
- PNG SHA256 `6b45693475c6662c4b0972728299ad709662796a4a75a1544f33a18c5beafe8c`。
- 解码 RGBA SHA256 `120e033ecfe616a38040bcaecd317eff9ab2fe4225b50c86f5e6d1968a069b16`。

## 保留的画面与所有权

- 直接加载实际 `Scenes/Crater.xml` 并使用现有 `scene.Crater`、环境烘焙和生产 `MatchMapShot.Process`，不是手画地图或占位底色。
- 保持 1024×1024、640 米全幅、half=320、1200 米俯视相机及现有冷色调处理。固定随机种子 1337、环境时间 1，静态底图隐藏烟柱/尘卷/浮尘/地风等瞬时粒子；保留建筑、道路、岩石、舰船、环境照明。玩家/敌人/目标由原动态图层负责，不烘进底图。
- 仅 `map.scene == 'Scenes/Crater.xml'` 请求烘焙图。其他地图与无 map 参数的离线烘焙仍走原捕获。
- 可选下载两个小地图文件，不进入强制 ResourceGate；失败/缺失/契约不符/输入 checksum 过期/图片尺寸不符/10 秒未完成均回原捕获，不阻断旧地图包。
- 读取后核对 11 项运行资源（约 3.08 MB）的大小及引擎 checksum；完整 1145 输入在打包前校验。
- 成功路径不创建 RT、捕获相机、复制场景或逐像素 Lua 调色。仅上传已处理 Image 到一张独占 Texture2D；Take 后由现有 minimap 持有并释放。取消后的下载回调不触碰销毁对象。

## 实际证据与限制

- 原生实际生成：`.tmp/match-map-bake-2026-10-15T13-47-27-005Z/`；`native.json` 内尺寸、非均匀真实像素、保存与相机释放断言通过。采样 299 种颜色，全图解码 327 种颜色、所有 alpha=255，实际图片已打开检查北向、要塞/道路/舰船布局。
- 3 项 native checksum 与 Node SDBM 算法逐项一致；发布与最终 `check` PASS。
- 实际 capture+tone **22,055 ms**，这是离线成本，不是加速后的玩家进场时间。完整 9000 帧 validator 167,538 ms，整体 **FAIL**：4 帧超过 100 ms，最长 15,589 ms。引擎 stderr 另有默认 Cube/Day/DaySpecularHDR.dds 与 themis_x64.dll 错误；不得写成引擎错误 0。
- 实际生产 Lua + 引擎 stub 离线检查 41/41 PASS，证据 `evidence/match-map-bake-offline.json`：下载、直接读取、不分配 RT、有效契约、checksum/缺失/尺寸/下载失败回退、超时、取消、Take 所有权、事件重载。
- 尚待 root 新统一包真实 Web 验证 `mapCapture.baked == true`、实际地图纹理及进场时间；离线测试不能替代该项。平台若改写 Lua/场景字节，checksum 会安全回退，但必须实测确认是否命中。
- 已发布图片来源是真实本次引擎 capture。构建工具自身尚未包含在 1145 输入中；工具变更应重新烘焙，不应仅复用旧 capture 签新算法。

## 可逐条验收

- [x] 重复生成/输入冻结/资产哈希与校验命令可运行。
- [x] 原生产调色、尺度、方向与坐标保留，真实底图已查看。
- [x] 缺失/过期/超时/取消回退的生产 Lua 离线检查通过。
- [x] 捕获相机释放、纹理 Take 与销毁所有权有检查。
- [ ] 新统一包 Web 命中 baked 路径，PC 与 20:9 实际图片对照。
- [ ] 同包真实加载冻结量测与连续地图进出；不签手机/M1 性能。
