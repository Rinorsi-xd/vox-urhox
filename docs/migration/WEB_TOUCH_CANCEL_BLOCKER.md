# Web触摸取消：真实浏览器失败证据

基线：H5 2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a。
运行包：manifest-b3a7f84f，QA4271。非真机测试。

## 复现与结果

真实CDP触摸在建造车身上开始后40ms发送touchCancel。页面捕获到DOM touchcancel（不是touchend），但Lua移动建造收到普通PointerUp，于是执行释放放置。

- 20:9：取消前209零件，取消后211（镜像同时加2块）。
- 16:9：同一完整触摸流程也FAIL；细节在mobile-editor-web-16-9.json。
- 两比例工具、颜色、模式切换、实际放置/450ms长删、拖视角、车辆面板和回厅分别23项通过，Lua/资源错误0；总体仍FAIL，不能签收完整移动建造。
- 第一放置失败是选点落在加特林旋转禁区，真实规则正确拦截；保留blocked-placement-failed.json。第二次拖视角检查误读环绕yaw，改读真实FP相机forward，实际操作通过；保留forward-probe-failed.json。

## 根因边界

本地引擎Events定义TouchEnd仅TouchID/X/Y，无cancel标记，无TouchCancel事件。UI库订阅TouchEnd并直接HandleTouchEnd；公开UI.HandleTouchCancel与CancelPointer可以处理取消，但没有引擎取消事件能触发它们。Web运行时注册了DOM touchcancel，最终折叠为普通结束。

因此Lua不能可靠从一次正常松手的数据区分浏览器取消。不能靠延时、距离猜测取消，不能改只读引擎库或只改QA宿主并声称生产修复。需正式引擎提供TouchCancel事件或正式发布宿主提供取消桥；本项目当前未发现公开Lua/JS调用桥。

## 后续验收

平台接口补齐后，接UI.HandleTouchCancel，再跑当前真实浏览器测试和真机来电/失焦/多指中断；取消前后蓝图一致，所有held输入归零。当前聚焦丢失/页面切换和Lua显式取消已经有本地清理路径，不等于上述DOM取消通过。

证据：evidence/mobile-editor-web-20-9.json、mobile-editor-web-16-9.json（包含实际DOM事件时间线）、对应stats/tap/paint/more截图。
