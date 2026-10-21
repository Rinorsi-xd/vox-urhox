# P0：局部表面重建与静态查询复用

本轮仅做掉件后的增量表面生成、未变材质跳过上传、精确静态射线缓存与没有消费者的接触数据跳过解析。物理固定步长、12 次求解迭代、伤害和修复规则未变。未提交、未远端构建。

## 实现和边界

- `scripts/render/JoinedSurface.lua`：按零件属性及六个相邻面的实际遮盖结果缓存精确三角形。删除、修复、移动、旋转、换色和改组都会比较依赖；只重新生成变化的零件。
- `scripts/render/JoinedMesh.lua`：重复添加相同零件不标脏；未变化的材质流保留身份并跳过 `BeginGeometry/Commit`。仍按材质合批，变化材质仍整条上传，未实现 GPU 顶点区间更新。缓存随 mesh 释放。
- `scripts/render/RotorView.lua`：Bind 根据最终转台归属增删成员，保留存活 mesh，清理废弃 owner。
- `scripts/physics/Space.lua`、`Body.lua`、`scripts/drive/TrackWorld.lua`：仅 `fixedOnly` 查询缓存；原点、方向、长度、mask、排除对象和 owner 过滤都进入精确 key，命中与未命中都缓存，容量 512。返回点和法线复制，避免调用方修改缓存。静态体注册、注销、owner、包装 API 的位姿、启停、类型变更均失效。直接 native 形状、层和变换修改必须调用 `InvalidateStaticQueries()`；现有静态地形在注册前完成构造，移动靶和载具为动态或 kinematic。
- `scripts/audio/CollisionAudio.lua`：确认一个侧面接触后停止解码。
- `scripts/drive/ObstacleSlide.lua`：没有本步移动修正或持续 belly 支撑需求时跳过接触解码。

## 离线回归与 CPU 对照

运行 `python3 docs/migration/tests/run-p0-tests.py`，依赖已安装的 `lupa.lua54`。参考实现只读来自 Git `8eb7822c`，不会改写工作区或 Git。覆盖八种预制车、24 种旋转、损坏/修复/换色/改组/移动、密集结构、转台归属迁移、mesh 生命周期和静态缓存 key/失效/容量/返回值隔离。原始与新表面的顶点、法线、颜色和分组数据精确一致。

其中多数预制车 `g=0` 不使用 joined 表面；不能把 vanguard 的收益推算到所有车辆。密集结构删除一格只重建 5 个剩余邻件；vanguard 测例只重建 2 个。

运行 `python3 docs/migration/tests/run-p0-tests.py --benchmark`。2026-10-21，本机 Apple M1，Lua 5.4 CPU，21 次中位数：

| 用例 | 首次旧/新（ms） | 掉件旧/新（ms） | 重建邻件 |
| --- | --- | --- | --- |
| vanguard，350 零件 | 24.441 / 30.973 | 23.849 / 4.494 | 2 |
| 密集格，256 零件 | 15.698 / 20.649 | 15.507 / 3.638 | 5 |

首次缓存增加约 5–7 ms 和额外 Lua 常驻数据，换取后续局部重建减少。以上不含 GPU 上传、Bullet 或渲染，也不代表手机帧率或 330 ms 尖峰已解决。

## 官方 Runtime 验证：功能断言通过，完整验收未通过

使用 Maker 插件 `maker_validate`，没有启动已停止的普通预览。临时入口在验证后删除；可复用源码位于 `tests/P0NativeProbe.lua` 与 `tests/P0NativeAssertions.lua`，按注释复制进 `scripts/diagnostics` 后调用验证。

三轮原始报告保存在 `.maker/validation-evidence/<run-id>/`：

1. `c9206b01-c6d8-49f0-8756-8e2cc458ea6d`：FAIL。测试入口漏了 ResourceGate，模型未就绪；没有完成有效断言。修的是测试入口，未绕过生产资源门禁。
2. `abdc906f-56fc-41fe-a9c3-7015d42ebd7b`：both 模式，17 项原生功能检查完成，无 Lua 错误；4 项截图断言失败、没有有效 PNG，整体 FAIL。`TakeScreenShot` 返回 false；相对输出被 Runtime 重定向至 savedata，且官方截图虽然记载 captured，最终也没有 PNG。原脚本副本与原始报告均保留，不宣称视觉通过。加载与截图阶段有 526–1039 ms 尖峰。
3. `244ba42c-fe57-4ae6-88b8-a86751f925ed`：独立 validate 模式，仅验证功能，不再请求图像。19/19 断言通过（17 项功能与 2 项完成检查），覆盖真实 Bullet 射线、缓存复用、防污染、移动、启停、kinematic 切换、删除、真实 mesh 身份及掉件/修复。报告整体仍为 FAIL，前两运行帧记录 168.161 / 102.509 ms 尖峰，未调高阈值。该模式由 CLI 添加 `-graphicsheadless`，原始日志另有 UI/Bloom/Surface shader 编译错误和启动阶段 Cube 资源告警，不能当作渲染验收。

Lua 语法、8 个生产修改文件的 LSP 和 `git diff --check` 通过。普通预览保持 stopped；手机性能、视觉和 GPU 上传收益仍待真机/有效渲染验证。共享工作区另一个会话的画面设置与 ScenePath 改动保留，没有归入本轮 P0。
