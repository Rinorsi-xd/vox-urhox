# G2 工坊精选与详情导航

基线仍为 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本批读取 CURRENT_EXECUTION 后接续功能，不重启 G0；没有改光照、字体、GarageHud、公共加载或战斗模块。

## 已修缺口

冻结 H5 `shared/ui/workshop.js` 使用独立 `heroI` 和 `detailId`。打开任意详情、详情翻页、从 browse 返回精选，都不会覆盖原精选轮播位置。

迁移版共用 `ws.selected`：如精选 fox → 打开 miniScout 详情 → 返回精选，会把 miniScout 留作精选标题和购买对象；Carousel 只为 featured 数组创建图片项，故非精选车没有对应图。即使详情是精选车型，返回后也不应该丢失之前的轮播位置。

仅修改生产 `scripts/ui/Workshop.lua`：

- `featureSelected` 单独保存最后已经显示的精选车。
- 离开精选时先保存，返回精选时恢复；详情自己的 selected 仍用于标题、3D 预览和购买。
- 外层切页离开详情时回 browse，并将已有持久化 selected 键恢复为精选车，因此不需要改 GarageHud 保存字段。
- 恢复旧记录时若 selected 不属于精选，回到有效 featured 首项，避免空图。
- 异步 Carousel 完成选择后重建页面保留新选择；此前取消迟到图片更新的修复继续有效。

## 验收证据

`tools/migration/workshop-shop-oracle.cjs` 新增对冻结原始 JS `Workshop.detail()` / `view()` 的实际执行，生成 8 个精选 × 19 辆车 × 2 个来源页的 **304 种导航期望**，没有用目标实现生成期望。

`verify-workshop-navigation-offline.py` 使用实际 Lua Workshop.Create/Change/Key/Leave 和实际 Carousel，**1523 项 PASS**：详情标题与预览、详情购买对象、Escape 返回路径、精选图片存在与下载就绪、精选购买对象、轮播切换后重建、外层已有保存字段往返，以及旧无效精选状态恢复。

其余回归：原购买链 **448 项 PASS**，GarageHud 领取入口 **9 项 PASS**；真实延迟 gate 检查仍 `NO_BUG`，scorpion 详情与购买未被迟到 fox 替换。`git diff --check` 通过。

证据：`evidence/workshop-navigation-offline.json`，生产 SHA `c791e839d20824ef4482b5976e3fd6308dd63baf1ea1bce15ba4fd40867df178`。

边界：UI/渲染及下载 API 使用替身，未启动 GPU、浏览器或原生引擎；不签视觉或新包实跑。没有 commit、push 或部署。后续统一包实际检查：精选 fox → miniScout 详情 → 返回 → fox 图文与购买一致，详情翻页后同样恢复原精选。
