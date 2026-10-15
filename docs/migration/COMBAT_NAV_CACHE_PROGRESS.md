# 战斗道路缓存进度

## 2026-10-15 本批

- 基线仍为冻结 H5 `2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`，不重开 G0。
- 目标是消除战斗 AI 对静态道路数据的重复计算，不改变决策频率、随机数调用、道路宽度、寻路排序或玩法规则。
- 生产仅修改 `scripts/combat/EnemyDriverNav.lua` 与 `scripts/combat/EnemyDriverThink.lua`。
- `Graph` 按地图 nav 表及车辆 width 复用原顺序构建的图。地图表为弱 key，缓存不反向持有 nav；nodes 或 edges 整表替换会自动失效。
- 狙击寻点的“该节点是否接平路”改为一次建立索引，代替每个候选节点扫描全部边。

## 生命周期依据

- `CraterWorld`、`EnginePitWorld` 每次由 `CraterLayout.Begin` 读取独立 Layout；`Fill` 只补 heights / blocks，不改道路。
- `SalvageWorld` 从本次读取的 Gameplay 取得 nav。
- 当前用户脚本未发现道路 nodes / edges 的原地修改。若将来加入动态道路编辑，修改后需要替换对应表，或补显式失效接口，不能静默原地改坐标/宽度。
- 当前 Graph 调用者仅查询图，没有改动返回的 ids / adj。

## 已验收

- 无引擎窗口，使用 `.tmp/nav-python-deps` 隔离的 lupa **Lua 5.4**；没有修改项目依赖。
- `tools/migration/verify-nav-cache-offline.py` 执行 `check-nav-cache-offline.lua`，结果 **2104 / 2104 PASS**。
- 旧算法取自不可变构建 `.tmp/outgame-cached-1792063134142/scripts/combat/EnemyDriverNav.lua`，SHA256 `25e065fd2390e88cb61ad15caf6222dd29594f2f8a93e9e4f10bd28da69c16ab`。
- 三张实际地图：陨坑 116 节点 / 147 边，发动机坑 338 / 1530，打捞 845 / 908。
- 每图宽度 1、3、6、12、20、30.5、40；逐图结构/顺序、Nearest、168 条路径（ID、位置、确定性 jitter）、每个节点平边索引均与旧算法相同。
- nodes / edges 整表替换失效通过；GC 后临时 nav、nodes、edges、graph 均已释放。
- 证据：`docs/migration/evidence/nav-cache-offline.json`，含全部输入、前后生产脚本哈希。

## 尚未关闭

- 本批尚未进入新的统一 Web 构建；没有在本子任务启动第二个运行实例。
- 不据离线等价宣称帧率改善或战斗冻结关闭。主任务正独占不可变 before 包实测，再收本批缓存到 after 包进行相同路径对照。
- 已发现但本任务未修改：CarUnit.Flush 同步全车重建、AI 原生全命中射线数量、首次碎块视图生成与运行期特效几何重建。现有历史日志中的 Flush 单次 416ms 是优先量测对象。
