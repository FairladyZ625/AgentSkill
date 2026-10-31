---
name: zeyu-brain-search
description: Teaches agents how to search and navigate ZeYu-AI-Brain with direct search, Obsidian CLI, Agent Graph, and the Brain directory map. Use when an agent needs to find prior notes, project context, decisions, todos, people, documents, or accumulated knowledge in ZeYu-AI-Brain.
---

# ZeYu Brain Search

Use this skill when you need to find information in `/Users/lizeyu/Brain`.

This skill is read-first and search-focused. It teaches retrieval, source checking, and navigation. If you need to create, move, rename, archive, or govern Brain files, stop and load `zeyu-ai-brain-sop`.

## Quick Start

1. Identify what kind of thing you are looking for: todo, project, person, knowledge note, work doc, system prompt, reading note, or raw context.
2. Read [references/brain-map.md](references/brain-map.md) to choose the likely area.
3. Use direct search for the selected scope: start with the relevant Brain directory, then use Agent Graph relations, `obsidian-cli search-content`, or filesystem keyword search.
4. Open every likely hit from its canonical path and verify the original file before answering.
5. Treat an empty result as “not found in the searched scope,” never as proof that the Brain contains no such information.

## Required Reading

- [references/brain-map.md](references/brain-map.md): where things live.
- [references/retrieval-playbook.md](references/retrieval-playbook.md): how to choose memory, Agent Graph, Obsidian, or filesystem search.
- [references/query-recipes.md](references/query-recipes.md): direct-search recipes and scoped fallback commands.
- [references/source-verification.md](references/source-verification.md): how to decide whether a result is trustworthy.

## Hard Rules

1. Do not treat search summaries as truth. Always open the source note before making a factual claim.
2. Use scoped direct search for Brain/workspace documents; do not use `memory_search` as a replacement for full Brain search.
3. Use `memory_search` only for durable memory and prior-session recall.
4. For personal todos and commitments, start with `00-INBOX/todo-backlog.md`.
5. For project context, start with `05-PROJECTS/<project>/`, then search raw agent context if needed.
6. `LOCAL-LARGE-FILES/agent-context/` is evidence and history, not the current state source of truth.
7. If a task changes Brain files, switch to `zeyu-ai-brain-sop` before editing. To understand the system itself, use `zeyu-brain-guide`.
8. QMD and vector search are retired. Use `rg` plus frontmatter tags.

## Search protocol

1. Classify the request as memory, channel history, project, task, person, knowledge, or system configuration.
2. Start at the canonical directory from `references/brain-map.md`; use Agent Graph relations when the question is about entities or links.
3. Use `obsidian-cli search-content` or scoped filesystem search for text and filenames.
4. Read the source note, not only a filename or snippet, and retain the canonical path as evidence.
5. If nothing is found, report the searched scope and say that the result is inconclusive outside that scope.

## Optional Helper

This skill includes a small helper for scoped direct search:

```bash
~/.agents/skills/zeyu-brain-search/scripts/brain-search.sh search "todo-backlog"
~/.agents/skills/zeyu-brain-search/scripts/brain-search.sh search "Agora current status"
```
