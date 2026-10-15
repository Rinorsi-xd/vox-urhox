# 开篇同步构造的后续修复位置

基线继续为10月14日 `2b169a9964645f5f346a7158bcb14447f040814a`。本记录是当前代码的调用链检查，不代替性能trace；不重开G0。

## 15:40后实测推进

6d18072e自然Web、无PNG、单QA浏览器但保留用户Editor43020：实际开车46.9595m/命中/原27镜头到合同、游戏错误0；新增导弹观察因QA仅I.playing时输出状态失败，未到签约/门/大厅，保留原FAIL。只读探针已补广告montage实际状态，未改生产发射条件。PCM最大3205.67ms、94间隙，RAF最大1264.03ms、58冻结，连续性仍FAIL。

24个postwarm编译（旧b8为48）通过不可变包原metadata和运行时UUID标识规范化全部解析；20条日志与7个PCM间隙重叠，不能解释剩下87个。精确增量已实现：原EquipmentResources Box/材质/参数的Thruster/Hover、原Mote/Spot/Flow-Flare、真实MissileView4→1、实际Chip多→1。最终Flare/Chip补充后的短检待队列；此前14/14功能PASS/错误0仅覆盖前一版。不扩大所有地图预热。

源main.js:383已有covered时不画3D，OpeningHost.Shot按root授权使用现有SetSceneVisible，仅familiar/galaxy停背景3D/post，其余镜头恢复，保留原physics/时钟/真实截图。root拥有共享retained-post验收。

余下间隙的现有证据：78/94前后同shot同voice且Sound缓存恒定，55次无旁白；最差3次均处于sortie-play稳定step2/3、无编译日志，main-thread长任务重叠3203/2436/2139ms。IntroPage非合同不重建UI树；13个IntroAudio SoundSource初始化即持有，55Sound准备后缓存恒22583595bytes；不能归因为旁白首次解码。Lua堆反复78–91MiB只能提示分配/回收，不给CPU归因。源main.js:346传入dt封顶.05，目标OpeningHost.Tick当前.1，慢帧允许最多6而非源3个60Hz补步；已交root审定，只读分析未擅改公共物理。分析细节在`intro-natural-web-1600x900-retained-post-pool-images-6d18072e-analysis.json`的audioGapContexts。

15:54最终增量：Flare/Chip版14/14实际渲染短检PASS、运行错误0。root授权仅OpeningHost.Tick封顶改为源.05，保持原叙事/音频时钟；真实host.Shot familiar/galaxy/payslip及simulation实参加入实际29pass夹具，20/20功能PASS/Lua资源0，frame9 181.446ms>100ms使整体性能FAIL，原证据保留。只读QA方法计时已准备随下一自然Web一起跑，包含实际Tick/物理/演员/武器/渲染对象更新/UI/音频，不额外冷启动；明确有wrapper开销和ms粒度，不是无探针性能金标。

## 已证实的调用与证据边界

| 入口 | 当前同步工作 | 当前证据与处理 |
| --- | --- | --- |
| garage/crater切换 | `OpeningHost.UseScene -> GraphicsSettings.Show -> CraterPostProcess.New -> FilterGraph.New`，旧实现每次重建29个视图及HDR资源 | root已实现仅开篇借用期间、同scene/camera实例复用，14/14原生功能PASS、错误0；OpeningHost保留RetainPost/ReleasePost，暂停不排渲染、最终释放；下一Web包连续性仍待验 |
| m-build | 原先清理/重复创建431实际模型 | 已改准备期池化；源`.24s`底面弹出及`.3s`青rim，15项真实节点/变换/collector检查PASS。完整host29项PASS；下一Web包复测连续性 |
| m-drive | 旧`CarUnit.Spawn`重新Load/VehicleSpec/Graph/HP/WeaponSystem/431零件Bullet；`PlayerViewSync.Update`随unitSpawn调用`VehicleView.Rebuild`和`DriveView.Bind` | 已由IntroMontagePool提前准备被禁用原hero/实际DriveView，切镜转交原对象；21/21真实Bullet/431节点/取消检查PASS、错误0；完整host新增驾驶/导弹检查进行中 |
| 首次UI图片 | 旧`IntroPage.Image -> ImageCache.Get -> nvgCreateImage`首次上传 | 已实现IntroImageWarmup：下载后、共享UI真实VG内每frameNumber一原图，10图ImageCache/4脸既有portrait Texture2D，smile先行以避免隐式两图。ready等14项，关闭只删本次自有VG句柄。最终原生66/66 PASS、运行错误0；实际contact发现并修contain拉条，最终图已查看。未归因实际Web卡顿或宣称连续性通过 |
| charge/wreck漫画截图 | `FramePresented -> graphics.TakeScreenShot -> Image -> Texture2D.SetData` | 两次真实GPU读回及上传。必须保留实际战斗截图，不能预制图片冒充；公共Lua绑定尚未确认异步读回，需单独计时 |
| 55个原音频 | `IntroAudio.PrepareNext`在准备期一帧读一个Sound，整个开篇持有独立音频场景 | 页切换不销毁语音对象，已实现。Web PCM仍有最大2700.495ms间隙，不可用对象持有正确推导声音连续 |

## m-drive安全接入契约

已实现独立模块`intro.IntroMontagePool`，不修改共用CarUnit/Vehicle/PlayerViewSync；由IntroBattle显式拥有。

1. `Prepare(session,battle,hero,checkpoint)`在当前加载协程内创建**同原hero** CarUnit和DriveView。CarUnit的`externalControl/externalView=true,autoRespawn=false,combat=true`；原生`vehicle.native.enabled=false`，不插入`world.units/entries`。不把车停远处或藏到地下来替代禁用。删掉仅属于待机hero的初始`unitSpawn`，不得清空其他实际出兵事件。
2. `DriveView.New`使用现有checkpoint与retain回调，先转交pool的view持有再yield。IntroBattle须在创建pool前被session持有，才能在中途取消时清理。CarUnit构造本身尚未分帧；把工作放到无叙事音频的准备期不等于冷启动达标。
3. `SetWarmVisible(true/false)`仅控制待机DriveView，物理仍禁用。当前源驾驶准备镜头能看见hero的原模型/材质/武器布局，不能借用另一辆车的shader组合当覆盖证明。
4. `Activate()`只执行一次：处置旧已毁player和其DriveView；替换`world.units[1]`、`entries[1].unit`、`battle.player`。重建`entries[1].env=battle:Environment(newPlayer)`，否则武器环境closure仍持有旧shooter、击杀归属错误。绑定`session.vehicle/weapons/view`到已准备对象，启用真实native body，按原位置`Place/ResetPose`。不再调用`Spawn`或触发`PlayerViewSync`的model Rebuild。
5. 转移后的pool清空unit/view引用；此后普通session/world拥有并只释放一次。未激活时`IntroBattle.Dispose`必须释放pool的view/unit。世界活动名册仍为9辆，初始教学仍是玩家当前原车，不能提前把教学车替换成hero。

## 逐条验收

离线复核b8原始日志48个postwarm编译：idyll6、countdown2、sortie-play36、missile4，未改原始报告。`analyze-intro-continuity.cjs`现在可按日志精确24字符UUID匹配当前`.shader.meta`，输出sourcePath/defines，无法匹配保持null。已确认旧漏项含`Equipment/Thruster,Mote,Hover,Spot`、`WeaponFx/Band,Swirl`、`VoxGlowPaint/VoxDecor/VoxDecorDouble/CraterScatter`的POINTLIGHT变体、`Hangar/Glass`的RECTLIGHT、`Combat/MissileGlow`的INSTANCED。旧metadata无法解析项不可猜名。当前新增boot私有pointlight、武器batch、4实例导弹、原hero pool仅是针对性覆盖，新Web日志才决定是否消除遗漏。自然脚本37条增加真实missileLaunched；真实first-kill仍单独报告enemyHit，源15秒fallback不冒称命中。PCM/RAF门禁仍严格0个>250ms叙事期停顿；用户Editor背景保留需明确记入workload。

数量与调用进一步核实（冻结生产未改）：AssemblyFlash实际639组件，同Model/material保留4；SceneWarmup每8项提交后最终恢复全部再呈现2帧，因此有真实instancing提交机会。私有导弹4枚×body/glow共8组件，同2个Model/Material；1700帧原生日志boot已编译INSTANCED，但真实m-missile1627仍首次编译非实例MissileBody(DIRLIGHT/SHADOW)及MissileGlow，说明只预热4枚漏了剩1枚情况。下一自然Web若仍在叙事期出现对应冷编译，可只补1枚→4枚实际提交阶段。EquipmentEffects.Thruster依赖实际thrusterOutputs>0，Hover依赖hoverStates.force/emitHits；当前不Step物理、held Update(1,0)不会创建这些proxy，扩大collector范围无法覆盖。先量新包，不预先堆所有场景变体。

`verify-intro-montage-pool.ps1`已通过21/21，Lua/资源/引擎错误0，约7.4秒：实际CraterWorld、9辆原actor、Bullet、431原hero部件及DriveView；包含禁用体不积分/不被实际原生射线命中、真实毁车后同一body/view/431节点激活、attacker归属、重复激活、部分yield取消及普通Dispose。它没有装满整张静态碰撞，也不代替自然开篇连续性。

第一轮扩展完整host在1500帧截断，32项31通过，唯一失败为最终完成标记；实际m-drive已完成身份转交，还未到移动/导弹断言。保留`intro-warmup-montage-frame-budget-fail*`。1700帧重跑35项34通过/错误0，真实同对象转交、431部件、>2m实驾、实际截图均PASS；m-missile1605开始，最终标记早于3秒叙事时间到达再次截断，保留`intro-warmup-montage-1700-frame-budget-fail*`，不宣称整体PASS。后续夹具预算2000帧/200秒已准备但未重跑，优先下一个统一Web包自然全流程，增加真实导弹发射断言。未改变性能阈值。实际AssemblyFlash在frame722的boot内编译，已有完整日志证明。

- 准备前后实际活动名册9；待机hero禁用，不参与Bullet碰撞、源VehicleRay命中、AI选敌、统计或音效。
- 读取原431hero蓝图，所有模型/材质/武器/碰撞描述保留；prepare阶段可以yield和取消，无残留body/view/owner。
- 自然教学击杀/毁车仍正常；m-drive切换后同一批预建body/model对象身份不变，原位置/S弯/锁定/齐射均有效，武器归属是新player。
- 连续开篇两次和中途关闭均不泄漏；根app返回真实大厅，原音频/输入/教程恢复。
- 在同一不可变Web包独占重跑自然开篇，分别报告功能、实际第一击、postwarm shader misses、PCM间隙、RAF分位/冻结。以上通过才可缩小连续性FAIL范围；真实手机性能仍单列。
