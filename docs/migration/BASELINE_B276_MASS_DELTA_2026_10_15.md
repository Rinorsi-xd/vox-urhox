# 10月15日基线与碰撞质量增量

接续既有迁移，不重开 G0。本批按 root 授权激活已冻结、已逐文件校验的最新本地提交。

## 活动基线

- 源仓库 `D:/Rino_Project/Vox`，分支 `2026-10-15`，HEAD `b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 快照 `.tmp/outgame-source-2026-10-15T12-35-57-243Z`；选定迁移目录2168文件、548509862字节，内容 SHA256 `edd9d0de1b29843c739f0dfd13eb0086977d6f3b1422954f5c8cf31085232d68`。
- 这是既有冻结工具选定目录的快照，不是整个仓库34428 tracked文件：其余32260文件未纳入，不能声称全仓库冻结。
- `docs/migration/outgame-baseline.json` SHA256 `00580c77957bd5374737244b98cdc1a2becd6f85fcd348debac57b1d60961d60`。
- 原10月14日 dirty活动快照完整保留在 `baselines/2b169a9964645f5f346a7158bcb14447f040814a-working-snapshot.json`，SHA256 `07b28d90181f5df9c217c75392d3f8f5ac6d204b3044380dca9d3836d8ad92ac`；没有覆盖另一份clean Git manifest或删除旧证据。
- `tools/migration/verify-candidate-baseline.cjs` 逐文件校验快照SHA/长度和Git源blob；Windows git archive的1136文本文件仅允许严格LF转CRLF的差异。冻结前后源HEAD相同，源checkout只读未改变。
- 校验报告 `evidence/candidate-baseline-b276064942ae.json`。

## 实际增量

- clean10月14 Git HEAD与10月15 HEAD之间：品牌、3辆起步车、fox数据，以及VehicleSpec MergeBoxes质量分组变化。品牌和起步车/fox数据由 root/legacy 并线。
- 原活动基线是10月14工作区dirty快照，不等同该日clean HEAD；dirty旧快照对新快照还包含 `shared/controls/touchControls.js`、`shared/ui/perfMeter.js`、`three/src/main.js` 三处差异。root已确认这3处仅品牌字串，不能错记为控制或新玩法变化。

## MergeBoxes

`scripts/drive/VehicleSpec.lua` 本批仅改 MergeBoxes。与实际源最新函数相同，每个box只合入种子质量的0.5至2倍格点（含边界），基准是种子质量，不随增长更新；零质量只合零质量；保留原x、z、y贪心顺序和checkpoint。

- 源黄金脚本实际执行冻结JS：`tools/migration/source-merge-boxes-golden.cjs`。
- `tools/migration/verify-merge-boxes-offline.py` 实际执行Lua5.4的生产函数，并与最新源比较；114案例、91016断言PASS，110案例相对旧版改变。
- 覆盖零质量、半倍/两倍与临界外侧、负坐标、24种旋转、总质量/中心/half/COM/checkpoints。
- 4格5kg车身加12格0.15kg装饰长排：旧单box COM z=3.75m，新2box COM z=1.080275229357798m，总质量保留。这是源算法修正，不是任意调驾驶常量。
- 生产SHA256 `76f9891bd5a58e86b31be0cdc86bbcc8c4201ccbc69a56737183cf3213e75025`。
- 报告 `evidence/merge-boxes-b276-offline.json`。未以离线一致宣称真实Bullet驾驶手感、Web帧率或整体G1验收通过。
