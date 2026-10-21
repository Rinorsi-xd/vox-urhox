# rt-orientation-check

渲染目标（RT）上下翻转（UV / Y flip）的 GPU 现场检测与自动翻正工作流，供 AI Coding Agent 作为 skill 使用。

## 安装

把整个目录复制到对应 agent 的 skills 目录（目录名建议保留 `rt-orientation-check`）：

```bash
# Claude Code
cp -a docs/agent-skills/rt-orientation-check ~/.claude/skills/
# 或项目内
cp -a docs/agent-skills/rt-orientation-check .claude/skills/

# Codex / Cursor / Gemini 等：按其 skills 目录约定放置，SKILL.md 为入口
```

安装后，问 Agent「画面上下颠倒了 / 新增了一个 nvgCreateVideo 显示 RT 的功能」即可触发。

## 内容

| 文件 | 说明 |
|------|------|
| `SKILL.md` | 入口：四条路径归类、红线、流程 |
| `references/principles.md` | 方向图/哨兵原理，为什么 runtime 更新后仍有效 |
| `references/patterns.md` | 四条路径的接入代码 |
| `references/verification.md` | 自检、平台矩阵、升级回归、排障 |
| `project-files/scripts/render/OrientationMap.lua` | 8×8 GPU 方向图 + 哨兵（通用版） |
| `project-files/scripts/render/OrientedCopy.lua` | 相机 RT 快照的一次性 GPU 拷贝 |
| `project-files/scripts/render/OrientationSelfTest.lua` | 一屏自检，覆盖 A/B/C/D 四条路径 |
| `project-files/assets/Shaders/Orientation/*` | shaderinc、哨兵、拷贝、自检 shader |

## 使用前提

- 引擎提供 NanoVG（`nvgCreate`、`nvgSetRenderTarget`、`nvgCreateVideo`）与 SurfaceShader。
- 项目已有把 `Texture2D` 作为渲染目标并显示/采样的需求。
- 模板复制到项目后：`project-files/scripts/...` → `scripts/...`，`project-files/assets/...` → `assets/...`。

## 首次接入

1. 复制模板，接入一条路径（见 `references/patterns.md`）。
2. LSP 诊断无 Error 后构建。
3. `require('render.OrientationSelfTest').Start()`，在所有目标平台确认每个 FIXED 格都是「红上蓝下、绿点左上」。
4. 删除项目里旧的写死平台翻转，避免双重翻转。

## 注意

本仓库已有同类实现（`scripts/render/PortraitCheck.lua`、`scripts/render/OrientedCopy.lua` 及对应 shader）。在本仓库内请优先复用现有实现；模板用于新项目或其他项目迁移。

## 安装注意

- **必须是真实目录，不要用符号链接**：编辑器的「用户 Skill / Skills」面板只统计真实目录（实测链接不会被列出），Agent 的 skill 发现也可能跳过链接。
- 本仓库内可安装到运行时的 skills 目录（本机为 `/resources/runtime/agent/skills/`，通常通过 `.claude/skills` 访问）：
  ```bash
  rm -rf /resources/runtime/agent/skills/@normi_rt-orientation-check
  cp -a docs/agent-skills/rt-orientation-check /resources/runtime/agent/skills/@normi_rt-orientation-check
  ```
  共享源更新后需要重新执行上述复制（运行时副本不会自动同步）。
- 目录名前缀 `@` 表示作者命名空间，与本仓库其他 skill 保持一致。
