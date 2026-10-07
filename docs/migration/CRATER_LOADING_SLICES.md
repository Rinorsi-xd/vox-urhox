# 地图数据解析与碰撞准备分帧

此前准备阶段配置 3 ms 合作式预算，但地图布局一次性读取、解析、归一化 3 MB 数据；进入 checkpoint 前已经阻塞。观测到完整准备片段 84 ms，其中 Layout.json 读取约 77 ms。不能用“有协程”代替实际帧预算检查。

## 当前实现

- `core/ResourceData.lua` 通过 ResourceCache 打开文件，批量读入临时 VectorBuffer，关闭文件后转成 Lua 字符串并单次解码。移除了 JSONFile 解析 → ToString → cjson 重复转换和多余 native JSON DOM。整数归一化保留。临时缓冲及时 Clear，读取失败也先关闭文件。直接 File.ReadString 的逐字节文件读取实测更慢，未保留该中间方案。
- `tools/migration/crater_layout.py` 将同一份源布局分成小型 Layout.json 元数据和 59 份数组片段，当前最大片段 75,633 字节。完整的 103,041 个物理高度和 2,066 条建筑记录保持原值、原顺序；生成器从输出重组后与源逐项比较。完整源数据仍在转换输入 Manifest.json，运行包不再额外保留旧大 Layout.json。
- `drive/CraterLayout.lua` 先构造带空数组的布局，再逐片读入并在片段间允许让出。CraterWorld 构造函数不在中途挂起：世界先交给 loader 持有，Fill 在其后开始。因此解析中取消也有明确清理对象，不靠遗留协程等待 GC。缺片、错误顺序、数量不符直接失败，不能激活半张碰撞图。
- `drive/CraterPhysics.lua` 在同一块未提交的地形几何内部按行检查预算。保持 100 块地形碰撞体、原三角形、楼板/开口及 153 个大石块碰撞，不以增加粗略盒子或删碰撞换速度。建筑和石块检查间隔分别细化到 4/8 条。
- `SceneLoader` 记录总准备时间、准备帧数、分阶段最大片段；阶段为 data/terrain/hulls/boulders。取消丢弃部分数组，退出清空世界的布局引用。地图仍在全部准备并完成环境光照后激活。

重新转换时 `compile-crater.py` 会生成布局片段并登记 Resources.json。`crater_layout.py` 单独执行只重写布局元数据/片段；分发前仍需通过完整编译流程更新资源清单。读取入口必须是 `CraterLayout.Begin/Fill` 或同步工具用的 `CraterLayout.Read`，不能再把元数据文件当成完整高度数组。

## 本轮证据

`verify-resource-loading.ps1` **43/43**：分别在数据只解析一部分时、已经创建部分原生碰撞时取消；验证高度缓冲释放、布局引用清空、大厅保持活动，然后重试成功。另含下载回调隔离、准备失败、环境烘焙等待和重试。完整游戏地图回归 **58/58**，建造实际会话 **42/42**；这些报告均零验证期 Lua/资源/引擎错误。

独立运行记录的最大准备片段从 **84 ms 到 22 ms**；当前 data 22 ms、terrain 5 ms、hulls 11 ms、boulders 3 ms，总准备约 629 ms，分布到 170 帧。元数据文件本身约 1 ms；多数片段约 0–2 ms，但仍出现超预算峰值，未确定每个峰值的分配/GC/原生调用占比。前后测试取消次数不同，不将两个独立运行记录当作严格基准或稳定帧率承诺。原始记录见 `evidence/resource-loading-before-raw.json`、`resource-loading-metrics.json`、`layout-loading-comparison.json`。

建造会话的旧测试期望弹窗立即销毁，与现有原版 160 ms 退出动画不符。测试现检查先释放输入，再推进既有 DialogHost 完成退出释放，没有改 GUI 行为。

## 未通过与范围

更新（2026-10-07）：24 种面板及活动空间规则已同步，实车放置/保存/重载/进图往返已验证。源后续新增三个转轴与组合块行为仍未同步，详见 CURRENT_SOURCE_DRIFT.md。

3 ms 是合作式目标，仍有 22 ms 峰值，不能声称全部达标。场景安装、渲染、GPU 首帧和总加载时长不由这里的 prepare 指标覆盖。地图仍是按所选整图加载，数据分片并不是地理区域边走边下载；没有验证真实远端弱网或骁龙 845 持续负载。热重载目前覆盖范围有限，也不能因直接读取文件就宣称任意状态热迁移完成。
