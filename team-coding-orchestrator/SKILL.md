---
name: team-coding-orchestrator
description: Orchestrate team coding work across Codex, Claude Code, and Gemini CLI with a tmux-first workflow. Use when users ask to manage multi-agent coding tasks, split implementation/review/summarization responsibilities, enforce model routing (Claude plan=Opus, code=Sonnet), or monitor live progress while delegating coding work.
---

# Team Coding Orchestrator

Run multi-agent coding work with fixed role routing and observable progress.

## Core routing policy

Always follow this role split unless the user explicitly overrides:

- Codex: implement backend and complex logic
- Claude: frontend implementation and review
  - planning/modeling: `claude-opus-4-6`
  - code writing: `claude-sonnet-4-6`
  - search/scouting/find-information tasks: `claude-haiku-4-5-20251001` (cost-optimized)
- Gemini: summarize outputs and perform second-pass review (docs + code)

Gemini policy:

- Use login-based Gemini CLI flow
- Do not introduce Gemini API key flow unless user requests it

## Runtime mode selection

Pick runtime by task type:

1. **tmux-first (default)** for interactive or visible collaboration
2. **background process fallback** for unattended long-running jobs

Prefer tmux whenever the user wants visibility into progress.

## Bundled script

Use bundled script:

- `scripts/agent-stack`

Recommended env (`~/.config/agent-stack/env.sh`):
- `ANTHROPIC_API_KEY`
- `CLAUDE_BASE_URL`
- `CLAUDE_MODEL`
- `DISCORD_WEBHOOK_URL` (for completion notifications)

The script supports:

- `up` / `down` / `status`
- `task [--notify <bot_id>] <agent> "prompt"`
- `watch <bot_id> <agent>` (attach completion watcher to running task)
- `send <agent> <raw shell command>`
- `tail <agent> [lines]`
- `doctor`

## Standard operating flow

1. Run `scripts/agent-stack up`
2. Run `scripts/agent-stack doctor`
3. Dispatch tasks by role:
   - Codex for backend logic
   - Claude Opus for plan, then Sonnet for coding/review
   - Gemini for summary + second review
4. Use `scripts/agent-stack tail <agent>` to inspect progress
5. Dispatch long tasks with notifier enabled, e.g. `scripts/agent-stack task --notify <dispatcher_bot_id> claude "..."`
6. Report milestones to user (started, in-progress, blocked, finished, ETA)
7. Do not "dead-wait" long CLI jobs: actively tail/checkpoint and send periodic progress updates
8. Avoid fixed short timeouts for long tasks; prefer tmux/background + watcher
9. Run `scripts/agent-stack down` after completion (or keep session if user wants continuity)

## Claude model routing commands

Use explicit models for Claude tasks to avoid default-model drift.

Plan with Opus:

```bash
scripts/agent-stack send claude "ANTHROPIC_BASE_URL=https://gaccode.com/claudecode ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY claude --dangerously-skip-permissions -p --model claude-opus-4-6 'Create an implementation plan for: ...'"
```

Code with Sonnet:

```bash
scripts/agent-stack send claude "ANTHROPIC_BASE_URL=https://gaccode.com/claudecode ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY claude --dangerously-skip-permissions -p --model claude-sonnet-4-6 'Implement frontend changes for: ...'"
```

Search/scouting with Haiku (cheap mode):

```bash
scripts/agent-stack send claude "ANTHROPIC_BASE_URL=https://gaccode.com/claudecode ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY claude --dangerously-skip-permissions -p --model claude-haiku-4-5-20251001 'Find relevant files/specs for: ...'"
```

## Response contract to users

When coordinating work, provide concise updates:

- what is running
- what finished
- any blocker requiring user input
- next step

Use templates and examples from `references/routing-playbook.md` when needed.
