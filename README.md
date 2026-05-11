# AgentSkill

[![skills.sh](https://skills.sh/b/FairladyZ625/AgentSkill)](https://skills.sh/FairladyZ625/AgentSkill)

OpenClaw 与常用 Agent 工作流的 Skill 集合。本仓库按开放 Agent Skills
生态组织，可直接用 `npx skills add` 预览和安装。

## 使用 npx 安装

先预览仓库内可安装的 Skills：

```bash
npx skills add FairladyZ625/AgentSkill --list
```

安装全部 Skills 到当前项目：

```bash
npx skills add FairladyZ625/AgentSkill -y
```

安装指定 Skill 到当前项目：

```bash
npx skills add FairladyZ625/AgentSkill --skill zeyu-docs-retrieval
```

安装指定 Skill 到 Codex 全局目录：

```bash
npx skills add FairladyZ625/AgentSkill \
  --skill zeyu-docs-retrieval \
  --agent codex \
  --global \
  -y
```

验证全局安装结果：

```bash
npx skills list --global --agent codex
```

> 不带 `--skill` 会安装仓库内全部 Skills。建议先运行 `--list`，再按需安装单个 Skill。

## Skills

当前仓库包含 17 个根目录 Skill：

```text
add-component
agent-teams-playbook
build-feature
docs-review
explore-recipes
find-skills
obsidian-study-vault-builder
openclaw-vault-guide
refactoring-ui
team-coding-orchestrator
ui-design-system
ui-ux-pro-max
vercel-react-best-practices
vue-best-practices
web-design-guidelines
xiaohongshu
zeyu-docs-retrieval
```

## OpenClaw 核心 Skills

### openclaw-vault-guide

用途：OpenClaw 的文档库快速上手指南。

何时使用：启动时、忘记工作流时、不确定文件位置时。

关键文件：

- `SKILL.md`：快速上手指南
- `HANDOVER.md`：完整交接文档，适合首次阅读

### zeyu-docs-retrieval

用途：文档库检索工具，提供三合一检索方案。

何时使用：生成 briefing、派发任务、查找历史方案时。

核心命令：

```bash
zdr snapshot              # 获取最新上下文快照
zdr zeyu-status           # 获取泽宇当前状态
zdr team-status           # 获取团队负载
zdr schedule              # 获取本周排期
zdr decisions             # 获取待决策事项
```

## 首次启动

1. 阅读 `openclaw-vault-guide/HANDOVER.md`（完整交接文档）
2. 阅读 `openclaw-vault-guide/SKILL.md`（快速上手指南）
3. 阅读 `zeyu-docs-retrieval/SKILL.md`（检索工具文档）
4. 测试生成一次 daily briefing
5. 开始工作

## 自我优化

如果你发现这些 Skills 有问题或需要改进：

1. 直接修改对应的 `SKILL.md`
2. 记录改进原因到 `/Users/lizeyu/Documents/ZeYu-AI-Brain/01-CONTEXT/成功模式/`
3. 通知泽宇你做了什么改进

---

最后更新：2026-05-11
