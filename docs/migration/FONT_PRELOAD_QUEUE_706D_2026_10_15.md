# 706d Regular 字体与首启队列复核

只读复核现有冻结包、manifest、引擎内置资源和真实 Web 日志。新增离线工具与本报告，未修改生产代码、字体、配置或运行任何浏览器/native。此报告不替代真实网络请求记录。

## 结论

1. **预加载选择与预算层没有按内容 hash 合并两个 Regular 字体。** 项目与引擎的两个不同 UUID 都在重建队列中；这个队列精确匹配真实日志的 `Found 3547 preload files`，Windows 变体字节总和为 124,964,928 B，即 119.175842 MiB，四舍五入正好为日志的 `119.2MB`。
2. **两个字体确为相同字节，非短 hash 碰撞猜测。** 已将冻结项目字体与 `UrhoXRuntime.data` 内引擎字体逐字节比较，SHA256 均为 `9c120f0a849bc0aa5048daae2a3c0f6eecd828b5b33fce682a9622833f5feea6`。
3. **移除项目副本的确定收益是少一个项目资源条目及 8,122,324 B 项目原始资源。不能直接签实际首传减少 8 MB。** 日志只有 `Need to download 3545` 和组完成计数，没有逐 UUID 的缓存命中或 HTTP 请求。因此这两项排除具体是谁、下载器后续是否共享请求/缓存，不能从 3547→3545 反推。
4. **没有证据表明这项修改会减少字体解析次数或字体对象。** 消费者仍会调用 `nvgCreateFont` / `GetResource('Font',...)`；仅将相同路径解析到引擎字体没有删掉调用、NanoVG 上下文或现有对象。对象和解析节省必须另行测量。

## 可复验工具

```powershell
node tools/migration/audit-font-preload-queue.cjs `
  .tmp/outgame-cached-1792072535275 `
  docs/migration/evidence/combat-performance-2026-10-15T13-56-49-208Z `
  docs/migration/evidence/font-preload-queue-706d/report.json
```

结果：`ADMISSION_REPLAY_MATCHED`，8 项校验全部通过。输出包括全部 3547 项队列、各项 UUID/hash/变体尺寸/asset 名/入选原因及 6 个输入文件 SHA256。该工具依赖已经下载的固定引擎 manifest 与本机冻结包，不会访问远端或改动它们。

来源：`manifest-706d3d0b.json`，Lua 指纹 `2bfcec5e7a9851ca7da857a59f0f70b999c41b25a3b5c8fa8b405e3cd8eb1fda`。真实日志为 `evidence/combat-performance-2026-10-15T13-56-49-208Z/console.log` 第 386–390 行。

## 为什么先前静态加法对不上

需要按真实源注册顺序解析 UUID：game → engine-startup → official-res → engine-res → urhox-libs。跨源同 UUID 后注册覆盖先注册的定义，而不是简单把各 manifest 本地条目相加。直接 preload 组及项目 blocking 条目作为起点，再补入其 blocking 引用闭包。`boot#refs` 中非 blocking 媒体不全部加入。

然后需要选实际 Windows 平台的 `size@windows` / `hash@windows`。日志虽显示 GLES，平台仍选 Windows 变体；这也解释日志中下载 `assets@windows.7z` 的行为。只加原始 `size` 会得到 116,176,950 B，错误低估约 8.79 MB。

| 解析后的所属源 | 队列条目 | Windows 变体字节 |
| --- | ---: | ---: |
| game | 2451 | 59,525,084 |
| engine-res | 928 | 61,886,697 |
| urhox-libs | 157 | 3,335,062 |
| official-res | 11 | 218,085 |
| 合计 | **3547** | **124,964,928** |

若按 `内容 hash + 扩展名` 合并，只剩 2735 项，和日志 3547 项不符。这个对照证实的是**预加载选择层**的粒度，不是下载器内部物理传输的实现。

## 两个 Regular 的身份

| 项目 | 项目字体 | 引擎字体 |
| --- | --- | --- |
| UUID | `ELeauduyxGP3gKRqijtMiQpO` | `CURqsaXDFUNd1JdtV4GY6WaO` |
| hash | `729d48cb` | `729d48cb` |
| 字节 | 8,122,324 | 8,122,324 |
| 组 | boot/default | full/default |
| asset 名 | `ELeauduyxGP3gKRqijtMiQpO-729d48cb.ttf` | `CURqsaXDFUNd1JdtV4GY6WaO-729d48cb.ttf` |

请求资源名和所属资源卷不同，普通 HTTP URL 缓存不会仅凭字节相同而自动合并它们；仍不能排除引擎在此之上额外做内容缓存。

引擎字体已经在初始整体下载的 `.tmp/web-engine/UrhoXRuntime.data` 中：该包 94,257,417 B，版本 `1.32.34/b1b5764a`，字体在资源数据区偏移 17,785,990 B。移除项目副本不会缩小这份 Runtime.data，也不会移除其中的引擎字体。固定 engine-res manifest 另标为 `1.1.925/60b25079`，二者版本身份不可混写。

## 解析和对象边界

- `scripts/ui/SourceFonts.lua` 的 `ResolveHelpSymbol` 仍按 `Fonts/MiSans-Regular.ttf` 读取帮助符号字形指标；`SourceDraw.InlineFont` 仍在对应上下文第一次使用时创建该字体。
- `scripts/render/PartsGallery.lua` 仍取得同一路径的 Font 用于 Text3D。
- 引擎 UI/启动 UI 可能有独立字体上下文和字体资源缓存。静态 manifest 无法证明项目副本导致多解析一次，更无法量出字形图集内存；报告不据此承诺解析/显存收益。

真正签收首次传输收益需要旧包/候选包同一冷缓存路线的请求级记录：两 UUID 的请求 URL、状态、完成字节、缓存来源，并单独扣掉 Runtime.data。候选还必须证明删除本地文件后，该虚拟路径确实解析到引擎 UUID，帮助符号与零件展览字体均无变化。当前只读任务没有实施删除。
