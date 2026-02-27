# OpenClaw Skills 目录

这个目录包含 OpenClaw 管家专用的 skills。

## 可用 Skills

### 1. openclaw-vault-guide
**用途**：OpenClaw 的文档库快速上手指南
**何时使用**：启动时、忘记工作流时、不确定文件位置时
**关键文件**：
- `SKILL.md` - 快速上手指南（5 分钟）
- `HANDOVER.md` - 完整交接文档（首次阅读）

### 2. zeyu-docs-retrieval
**用途**：文档库检索工具（三合一检索方案）
**何时使用**：生成 briefing、派发任务、查找历史方案时
**核心命令**：
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
4. 测试生成一次 daily-briefing
5. 开始工作！

## 自我优化

如果你发现这些 skills 有问题或需要改进：
1. 直接修改对应的 SKILL.md
2. 记录改进原因到 `/Users/lizeyu/Documents/ZeYu-AI-Brain/01-CONTEXT/成功模式/`
3. 通知泽宇你做了什么改进

---

**最后更新**：2026-02-26
**维护者**：OpenClaw（你）
