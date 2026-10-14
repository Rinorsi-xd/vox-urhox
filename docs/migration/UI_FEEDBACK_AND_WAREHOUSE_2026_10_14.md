# UI 反馈、打捞声音与仓库运动

## 来源

仍只读取冻结 H5 `2026-10-13` 分支提交 `90862445074e7e146da900037979ad97899ecf6c`，快照为 `.tmp/outgame-source-2026-10-12T21-18-23-463Z`。目标分支 `codex/h5-2026-10-13`。本批没有新主题、新图标、竖屏布局或光照调整；未上传、提审、发布 Maker。

## UI 修正

- 快捷格键盘焦点：原最终 computed style 为 `brightness(1.18)`，现在连原缩略图一起提亮，并保留透明覆盖。复用 UI ImageCache，不新增图片、字体、上下文或全屏滤镜。
- 卡片焦点图片：原最终 computed style 是 drop-shadow，不套快捷格的 brightness。来源夹具分别记录两者，避免把通用控件样式误套到卡片。
- 卡片快捷编号：原 `bottom:37px;height:20px`，恢复正确顶部及原行高。

原生 `verify-inventory-effects.ps1` 813/813 PASS，包括真实 GPU 黑底/alpha/不透明像素采样。截图 `inventory-focus-brightness.png` 已查看。`manifest-cbba6aaf.json` 的 PC 1920x1080、20:9 840x378 DPR3、4:3 1024x768 DPR2 局外回归均 PASS，运行错误数组为空。该构建随后仅增加仓库运动，不把前一构建的三端回归冒充后续全量回归。

## 打捞原音效

`import-salvage-audio.cjs` 校验冻结 `shared/ui/salvageRunHud.js` 哈希，在浏览器 OfflineAudioContext 中执行实际原 `tone(r)` 与 `heartbeat()`；仅在服务响应中增加导出封装，未修改原快照。导出六阶揭示及悬念心跳，共 7 个 48000Hz、单声道、16bit WAV，695348 字节。`RevealSounds.json` 记录来源和逐样本哈希，没有重新设计音色。

运行时 `audio/SalvageAudio.lua` 最多复用 4 个 SoundSource，跟随生产规则事件播放，原音高、默认音效音量 0.6。暂停、失焦、结算和销毁停止声音，不留延迟回调。七个声音仅打捞进场时请求，HTTP 传递依赖审计确认不在 boot 或 blocking。原生打捞 1132/1132、共用战斗 94/94 PASS；这些验证覆盖采样解码、真实事件、暂停和释放，不等于用户听感验收。

## 仓库运动

旧导出把天车和机器人直接烘进世界坐标静态批次，运行时没有关节可动。`export-outgame-scenes.cjs` 现在仅保留原 bridge/trolley/cable/load/trader/bot/head 七个节点，将对应模型烘到最近的原节点空间，其他模型继续静态合批。运行时 `WarehouseMotion.lua` 只更新原节点变换：天车轨道往返、小车横移、钢缆收放、吊箱升降、机器人身体微动和头部摆动。

原 5844 个三角形全部保留一次；批次数从 92 到 105，20 个批次依附活动节点或商人锚点，模型负载从 543112 到 544620 字节，仅增加 1508 字节。材质、灯光、纹理未调整。每帧没有重新生成网格，退出仓库释放活动节点。

来源样本 `source-warehouse-motion.json` 来自实际原 Warehouse.update 的 0、0.25、1、7.5、19、31、70、140 秒。原生 `verify-warehouse-motion.ps1` 887/887 PASS，覆盖全部本地位置/旋转/缩放、世界坐标、镜像坐标转换、批次父子关系、模型复用和离开释放。

## 最终预览与验收

普通 4206、QA 4204 使用 `outgame-cached-1791938751684 / manifest-bdd18fa1.json`。普通库存/声音 HTTP 身份与按需依赖检查 37/37、打捞/仓库 HTTP 身份 41/41 PASS；普通 main 不含 QA probe。

最终 `manifest-bdd18fa1.json` 三端打捞网页回归全部 PASS：PC 1920x1080 为 17 项、20:9 手机 840x378 DPR3 为 15 项、4:3 平板 1024x768 DPR2 为 15 项。三份报告捕获的意外运行错误均为 0。覆盖真实 UI 入场、仓库活动节点、商人机位、生产搜索揭示音、撤离、结果停声及返回；F4/F11/F7 仅将车放到源补给箱、提供一件稀有物品及移到合格撤离点，其余使用生产规则。报告为 `evidence/salvage-web-{pc,phone-landscape,tablet}.json`。

已人工查看三端仓库/商人及揭示、手机和平板结果页、PC 结果页，模型非空白且商人关节完整。三端仓库、商人、运行、搜索、揭示和返回共 18 张场景截图通过 RGB 与中心区域像素变化检查。纯 UI 的结算页有暗色遮罩，不套用 3D 场景的亮度变化阈值，以实际截图和结算控件/返回断言核验；未把截图非空白等同于视觉一致。前一 `manifest-cbba6aaf.json` 局外回归中 PC/平板各一次 QA 大 JSON 输出截断，经重新导出恢复，另记为 probeIssue，不称整份控制台无问题。

源投放/撤离/死亡运镜仍缺；钻头、MVP、翼面/新版机甲、完整源触屏流程仍需继续迁移。云存档已有实现，但正式账号刷新恢复及跨 key/多设备一致性仍待验收。仓库当前由运行时代码创建，没有独立 `Scenes/Warehouse.xml`，本批不新增一套编辑器场景。

本地引擎镜像的四条 aggregate archive HTTP 404 后备加载、原生启动 DDS/themis DLL 错误仍单独记录。没有实机 M1/手机持续帧率、温度、内存或冷网络验收，不以桌面模拟结果承诺真机稳定帧率。
