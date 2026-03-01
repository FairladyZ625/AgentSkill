---
name: kb-governance-review
description: Run read-only governance audits for ZeYu-AI-Brain knowledge base quality and compliance. Use when checking 00-09 folder standards, task skeleton completeness, active-vs-done consistency, "done but not archived" drift, missing required fields, and cron/repo health; produce actionable issue lists and assign fixes to responsible agents without editing files.
---

# kb-governance-review

Run read-only audits. Never modify files. Never archive files directly.

## Audit modes

### Small audit (every 1h)
Run fast checks with low token usage:
- Check repo cleanliness for `.openclaw`, `~/.openclaw/workspace`, and `ZeYu-AI-Brain`.
- Check cron health (`lastRunStatus`, `consecutiveErrors > 0`).
- Check `03-ACTIVE-TASKS/进行中任务.md` for tasks marked done but still listed active.
- Check basic task skeleton for active tasks.

### Large audit (every 6h)
Run full governance checks across `00-09`:
- Validate task skeleton (`00-CURRENT`, `02-WORKING`, `03-PUBLISHED`, `99-ARCHIVE`).
- Validate template-required fields in `00-CURRENT.md` and `00-任务简报.md`.
- Validate state consistency between task files and active board.
- Detect unfinished closure steps (done status but no archive movement).
- Detect weak-quality entries (empty conclusion/evidence/receipt fields).

## Output contract

Write findings into a report file under:
- `/Users/lizeyu/Documents/ZeYu-AI-Brain/07-REVIEWS/KNOWLEDGEBASE/`

Use filename:
- `review-YYYY-MM-DD-HHMM.md`

Use template:
- `templates/review-report-template.md`

If file write is blocked by permissions, post full Markdown report in channel and @Codex Main to persist it into `07-REVIEWS/KNOWLEDGEBASE/`.

## Response contract (channel)

When issues exist:
1. Send concise summary to main Discord channel.
2. Include severity counts (H/M/L).
3. Mention responsible agents for fixes.
4. Keep message as conclusions + actions only.

When no issues exist:
- Send one-line green status, no verbose details.

## Guardrails

- Read-only behavior only.
- Do not run destructive commands.
- Do not edit knowledge base files.
- Only notify and assign remediation.
