# 开篇回厅下载回调长帧：35b实测

## 构建与结果

H5基线10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`。实际运行最终冻结 `manifest-35b14da3.json`，522 Lua，普通4425/QA4426，同构建HTTP审计通过。2026-10-16 03:23:04Z至03:26:32Z运行，浏览器正常关闭。

本轮仅公开广告Escape跳过→通讯→真实第三选项/v07→登记签名→盖章/闸门→大厅，不是完整自然开篇，也不覆盖驾驶/工资条/蒙太奇。32功能检查PASS，运行错误0；4:3、16:10、20:9登记字段/签名/条款适配通过，root查看4:3实际截图。整体连续性FAIL，未更改门槛。

证据：

- `evidence/intro-return-web-1600x900-manifest-35b14da3-return-profile.json`、同名前缀log/audio-timeline.json/exit.cpuprofile。
- `evidence/intro-return-manifest-35b14da3-cpu-summary.json`：实际CPU采样离线归因，保留输入SHA256。

## 已量到的事实

RAF P95 16.720ms、P99 33.360ms、最大450.330ms；两处超过250ms。音频853回调/826非零，最大回调间隔474.900ms，两处候选，不等同已听到断音。

最长441ms主线程任务：network-callback-observed-stack约404.380ms；次长345ms任务约312.222ms在同类回调链。两者self热点是`_emscripten_get_now`、`now`和未命名WASM函数14591，调用路径包含xhr.onload/reportSuccess/doCallback/callUserCallback。不是已解码的原生锁符号，不能据此声称唯一锁拥有者或声音解码根因。

回厅时实际发起声音资源：`Sounds/Music/hangar-04-lost-mining-belt.mp3`和`Sounds/Ambience/amb_hangar_a.wav`。新版只读探针记录请求/完成/队列观察/现成资源观察/播放观察，音乐完成后约69ms观察到声源，环境音约23ms。观察时间是上界，不是native EndLoad耗时。此前还有25资源组完成日志，需区分教程组和声音组，不能把所有下载耗时算给音乐。

该轮Lua音乐Update/PreparePending最大4ms，环境音Update/Prepare最大1ms，显式资源释放最大61ms且早于回厅；开场退出合计78ms。回厅阵列资源已退役、无遗留陨坑工作，不支持“另一个地图还在跑导致本次441ms”的解释。

## 后续验收

先用独立最小Web下载路径复现完成回调，分别验证仅置标记与锁内cache调用；查阅原生符号或引擎实现后再给根因定论。不修改引擎库、不删除原声/演出、不降低连续性门槛。生产候选必须重新构建、同包运行；这次带CPU采样，不与此前完整播放直接算性能提升百分比。
