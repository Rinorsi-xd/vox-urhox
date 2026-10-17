# Web 炮塔范围冷暖调用实测

本轮真实网页对局确认：部分首次受损长帧包含对实际车辆蓝图的冷炮塔范围计算。不能把这一结论扩大为全部卡顿的原因，亦不作为优化后帧率验收。

## 运行与完整性

- 冻结生产包 `2a92fa6d`；隔离派生 `.tmp/monitor-combat-turret-2a92-c/identity.json`。只改派生main和TurretRange三个可逆观察入口，移除观察行可恢复原始完整SHA。生产未改，没有加载期priming候选。
- `evidence/monitor-combat-turret-2a92-c/report.json`：PASS/CLOSED，Runtime和HTTP错误0。root串行运行，公开匹配入口后受控摆位、实际开火破坏45秒，再公开返回大厅。
- 8辆实际车辆、7个AI，1143发射击、1406次命中，玩家受伤889；最低781个零件。不是自然整局、手机或TapTap实测。
- 1235完整帧/45089ms，均值36.509ms（27.39FPS）、P95 67ms、最大128ms，11帧超过80ms。这是额外分段监控下的归因采样，与旧轮次工作量和破坏时序不完全一致，不能相减宣称改善或回退。
- 独立离线解码校验完整UTF-8/FNV传输、118次For逐帧调用、Prepare/Evaluate及冷暖调用数与完整帧对齐；1227帧间隔精确、8帧差1ms，无补帧插值。结果为 `independent-turret-attribution.json`。

## 实际调用

| 分类 | 调用数 | For累计 | Prepare累计 | Evaluate累计 | 单次For最大 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 实际蓝图无缓存 | 5 | 228ms | 0ms | 226ms | 70ms |
| 完整复用 | 52 | 9ms | 0ms | 0ms | 1ms |
| 重建上下文并复用范围 | 0 | 0ms | 0ms | 0ms | 0ms |
| 已有缓存、重新Evaluate | 61 | 245ms | 14ms | 219ms | 5ms |

计时为整数毫秒墙钟；Prepare的0ms表示低于本次计时分辨率，不表示没有执行。For包含Prepare/Evaluate，不可累加嵌套耗时。冷分类只表示该次实际bp在For入口没有缓存；共享武器样本与资源可能已经加载。

三个长调用位于engineFrame 3848/3850/3855：整帧112/128/114ms、For 70/70/69ms，其中Evaluate各69ms，Prepare均低于1ms。对应每辆实际蓝图首次记录的冷调用。另两次冷调用为10/9ms。

其余慢帧包含没有For的情况，也有For仅4-5ms而整帧83-89ms的情况。因此解决冷炮塔计算只针对首伤重建尖峰，不足以保证持续30FPS。平均脚本22.905ms/帧、平均2.189固定步/帧，持续模拟和未归因引擎时间仍需处理。

## 后续决策

加载期重新调用For的priming候选虽减少首伤，但增加总工作量，仍不批准合入，见 `PERF_DAMAGE_PRIMING_2026_10_17.md`。优先试验复用SpawnSpecCache准备阶段已经计算的数据，保持每车可变状态独立、真实伤损重新验证。另一个只删除且未影响采样命中的范围复用候选需要独立CPU前后对照；调用数减少不等于帧率提升。

失败的debug版本b保留FAIL/CLOSED，原因是Web禁用debug接口；本次c不使用该接口。c完成后专用QA4579已停止，普通4578保留。本报告不签收骁龙845/TapTap持续30FPS。

复算命令（输出文件名必须尚不存在）：

```powershell
node tools/migration/monitor-combat-turret-analyze.cjs docs/migration/evidence/monitor-combat-turret-2a92-c independent-turret-repeat.json
```
