# 死亡碎片视觉节点复用

## 当前所有权与冻结

2026-10-15本批 `legacy_audit` 只拥有 `scripts/render/CombatView.lua`、`scripts/render/VehicleView.lua` 和本文件/对应离线验证。主集成root负责运行与构建，g4负责存活Flush CPU/真实native timing，g5负责小地图。未修改CarUnit、Blueprint、VehicleSpec、TurretRange、碎片物理、数量、寿命或随机调用。

| 生产文件 | 冻结SHA256 |
| --- | --- |
| CombatView.lua | `96B09A6ED5024A65A8CAA3E43C617C05D8BC23F01B4239A42822363DF9F4C2DA` |
| VehicleView.lua | `C20FA1D5A06765E425B898642F954B1F250E66311EEB6AFC10AEAECE05DE2B5B` |

## 根因与改动

主集成提供真实native证据 `evidence/damage-native-timing-2026-10-15T12-48-18-043Z`：MEGA死亡Consume为250/302ms，而Debris物理为9/12ms。检查发现1611件MEGA全部走独立rig，绝大部分是静态shape；旧路径先Dispose整车显示再逐件AddPart重建碎片模型/材质绑定。

CombatView在执行kill/removal事件前，通过同一个part表身份寻找现有静态显示，转移到对应碎片。VehicleView只允许非Joined、非xray、非复杂segments、非weaponMotion的静态shape实例；保留同一节点、模型、材质和资源引用，重设原始局部位置、旋转、缩放。复杂动态rig/Joined继续原路径。未延迟任何碎片显示，当前Consume内所有part齐备。

转移后旧视图不再拥有该visual，最终碎片Dispose只释放一次；part表身份隔离不同车的同数字ID。准备出的碎片立即登记到CombatView所有权中，防止加载checkpoint取消时漏清理。

## 验证与边界

- 28条实际生产Lua控制路径检查通过：`evidence/debris-visual-transfer-2026-10-15T12-54-53-559016Z/report.json`。
- 覆盖节点/模型身份、跨车同ID、源坐标恢复、同帧完整part、复杂/Joined回退、旧车退休不销毁已转移对象、碎片结束清理、取消时全部节点/资源恰释放一次。
- 上述28条的Node、model是观测适配器；原生证据另见下一节，不能将离线结果写成Web/GPU或画面验收。
- `git diff --check`通过。生产已冻结给主集成，等待root单一Web构建的实际画面与操作验收。
- 当前复用范围为CombatView持有的敌车。玩家`externalView`由PlayerViewSync管理，仍走原碎片路径；未擅自扩展隐藏mask和玩家重生契约。

## 原生专项结果（2026-10-15更新）

g4的实际Windows/D3D11结果：`evidence/damage-native-timing-2026-10-15T13-05-13-104Z/result.json`，152/152断言通过，Lua错误0、资源错误0。节点身份、原生父节点转移与最终释放均通过。该次运行前后生产文件SHA一致。

| 项目 | 优化前Consume | 首轮优化后Consume | 最新复测Consume | 最新死亡整段 |
| --- | --- | --- | --- | --- |
| MEGA 核心击毁 / 战斗整车击毁 | 250 / 302ms | 25 / 27ms | 28 / 29ms | 42 / 44ms |
| raceCar 核心击毁 / 战斗整车击毁 | 37 / 43ms | 5 / 10ms | 4 / 8ms | 5 / 9ms |

最新数据见同目录`damage-timing.json`；首轮见`evidence/damage-native-timing-2026-10-15T12-57-47-377Z`。MEGA两条路径各验证1585个转移节点，raceCar各200个，均为同一原生节点身份，非重建替代。

这只关闭碎片转移的原生功能与本段CPU耗时检查。最新验证器整体`result`仍为`FAIL`：记录63条100ms以上的Frame time spike，最大2409.67ms（包含初始化等全程），不得据此宣称整场卡顿解决。原生测试fixture仍标注源提交`2b169a9964645f5f346a7158bcb14447f040814a`；它不是10月15日新三车实际驾驶/受损验收，也不是Web、GPU、手机或M1性能证据。

## 小地图独立只读复核（已交由g5继续）

检查g5当时的MatchMapShot/MatchMinimap/TrialSession接线（未修改）：capture、处理中Image、Take后的纹理及NanoVG video都有单一owner；取消/失败与正常HUD退出释放链完整，RT通过Retire。镜像X发生在Coord边界，顶视相机方向和源+x左/+z上匹配。

后续实际读回发现底图为纯灰/原始捕获为黑，不能将静态接线检查视为小地图完成。g5已用红盒诊断确认当前运行时使用旧`fogStart/fogEnd/fogDensity/heightFog`属性，单改新版`depthFog*`没有关闭雾；补设旧属性后，1200m顶视捕获中心恢复红色`[0.804,0,0,1]`。g5继续实现并验证完整雾状态恢复与实际地图捕获。192边大半平面擦除也存在严重重复填充成本，已交接精确alpha遮罩替代建议；最终以g5新证据与root实际Web画面验收为准。本批不修改小地图生产文件，也不重复运行窗口。
