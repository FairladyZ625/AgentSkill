---
name: zeyu-brain-guide
description: 快速理解泽宇的 Brain（~/Brain）：它是什么、目录怎么分、谁在写它、自动化在哪、和 Hermes 的边界、三台机器怎么同步。第一次进 Brain、要改 Brain 的结构/脚本/定时任务、排查 Brain 自动化或同步问题时使用。只找内容用 zeyu-brain-search，写入规则看 zeyu-ai-brain-sop。
---

# Brain 快速上手

Brain 是泽宇的个人知识与事务库：一个 Git 私有仓库，同时是 Obsidian Vault。人在手机和 Obsidian 上看，Agent 负责读写和整理。

## 三个技能的分工

| 要做什么 | 用哪个 |
|---|---|
| 理解 Brain 全貌、改系统本身 | `zeyu-brain-guide`（本技能） |
| 找资料、查事实 | `zeyu-brain-search` |
| 写入或移动文件 | `zeyu-ai-brain-sop` |

检索只用直接搜索：`rg` 加 frontmatter（`tags`、`domain`、`source_type` 等）。QMD 和向量索引已退役，不要再装回来。

## 目录

| 目录 | 放什么 |
|---|---|
| `00-INBOX` | 收件和待办，待办真相源是 `todo-backlog.md` |
| `01-PERSONAL-OPS` | 日报、排期、复盘、Agent 治理计划、每日上下文 |
| `02-PEOPLE-NETWORK` | 人物，入口 `_index.md` |
| `03-KNOWLEDGE` | 长期知识：`01-READING` 正式层，`02-WORKING` 处理层 |
| `04-SYSTEM` | 系统文档、迁移手册、`prompts/cron/` 定时任务 prompt |
| `05-PROJECTS` | 项目的活工作区 |
| `06-PERSONAL-DOCS` | 个人文档 |
| `07-WORK-DOCS` | 公司文档和对外时点凭证 |
| `08-SCREEN-MEMORY` | 屏幕记忆每日文档，服务自动写，不手改 |
| `09-ARCHIVE` | 归档 |
| `99-ATTACHMENTS` | 附件 |
| `scripts` | 脚本，入口 `scripts/INDEX.md` |
| `harness` | Harness 台账，用 `ha` 操作，不手改 |
| `LOCAL-LARGE-FILES` | 软链到 `~/LocalLargeFiles`，大文件和 Agent 过程数据，不进 Git |

## 谁在什么地方

| 东西 | 位置 |
|---|---|
| Brain 仓库 | `~/Brain`（三台机器路径相同） |
| Hermes 人格、记忆、工具说明 | `~/.hermes/profiles/<profile>/workspace/` 的 `SOUL.md`、`AGENTS.md`、`MEMORY.md`、`TOOLS.md` |
| Hermes 定时任务 | `~/.hermes/profiles/<profile>/cron/jobs.json`，多数只是指向 Brain 里的 prompt |
| 自动化脚本 | Hermes 工作区 `scripts/`，以及 Brain `scripts/` |
| 技能 | `~/.agents/skills`（GitHub：AgentSkill），Claude 经 `~/.claude/skills` 软链，Hermes 自有技能在 profile 的 `skills/` |
| 屏幕记忆 | 项目 `~/Projects/screen-memory-service`，运行数据在 `~/BrainLocal/` |
| 录音转写 | 项目 `~/Projects/transcription-asr-research`，夜间 `daily-audio-transcribe` |

Hermes 把 Brain 当知识库读写；人格和运行配置都在 Hermes 那边，Brain 根目录不放这些文件。OpenClaw 已退役，遇到 `.openclaw` 路径都是历史记录。

## 三台机器

| 机器 | 角色 | 连接 |
|---|---|---|
| `MacBook-Pro` | 主机，跑自动化和 Hermes | 本机 |
| Air | 副机 | `ssh macbook-air-via-tencent-prod` |
| 公司机 | 副机 | `ssh macbook-pro-company-via-tencent-prod` |

- 只靠 Git 同步，不用 iCloud。`~/Documents/ZeYu-AI-Brain` 已废弃。
- 主机 `com.zeyu.brain-safe-commit-patrol` 每 30 分钟自动提交并推送，`brain-git-guard.sh` 负责拦截。
- `gen_vault_index.py` 只在主机跑，且用 `--paths` 限定范围。
- `.smart-env`、`.obsidian` 工作区状态不用管。

## 改动系统时

1. 先看 `AGENTS.md`，涉及结构变更读 `zeyu-ai-brain-sop`。
2. 改定时任务：prompt 在 `04-SYSTEM/prompts/cron/`，调度在 Hermes 的 `jobs.json`。改 `jobs.json` 前先停对应网关，否则会被回写。
3. 网关：`launchctl bootout gui/$(id -u)/ai.hermes.gateway-<profile>`，再 `bootstrap` 对应 plist。bootout 是异步的，紧接 bootstrap 可能失败，要重试。
4. 记录迁移和系统变更：`04-SYSTEM/`，主文档是 `2026-10-31-主机迁移执行手册.md`。
5. 大批量 I/O 用 `nice -n 19`。这台主机在大量 I/O 时死机过。
