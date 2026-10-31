# Retrieval Playbook

## Tool Choice

Use the narrowest direct-search tool that fits the question:

- Agent Graph for entities, relationships, project/task links, and navigation.
- `obsidian-cli search-content` for vault note content and filenames.
- Scoped filesystem search for exact terms, paths, and system files.
- `memory_search` only for durable memory, preferences, decisions, or prior session recall; it is not a full Brain search engine.

```bash
obsidian-cli search-content "question" --vault ZeYu-AI-Brain
rg -n "keyword" /Users/lizeyu/Brain/05-PROJECTS/<project>
```

Use Obsidian CLI when you know a vault path and need to read a note through Obsidian:

```bash
obsidian read path="00-INBOX/todo-backlog.md"
```

Use filesystem commands for structure checks:

```bash
find /Users/lizeyu/Brain/05-PROJECTS -maxdepth 2 -type d | sort
rg -n "keyword" /Users/lizeyu/Brain
```

Prefer scoped search over scanning the whole vault, because bounded retrieval protects context and makes empty-result claims auditable.

## Search Strategy

1. Start with the user's words and correct likely speech-to-text terms from the voice glossary.
2. Classify the target as memory, channel history, project, task, person, knowledge, or system configuration.
3. Choose the canonical directory or Agent Graph entry point before searching.
4. Run a bounded direct search with `obsidian-cli search-content`, `rg`, or Agent Graph.
5. Open 2-5 promising source notes and compare current-state notes against historical evidence.
6. Answer with canonical paths, searched scope, and uncertainty where useful; an empty result is inconclusive outside that scope.

## Search Modes

- Agent Graph: entity, relationship, project, and task navigation.
- `obsidian-cli search-content`: vault content and filename search.
- `rg`: exact terms, identifiers, paths, and scoped source checks.
- `find`: directory and structure discovery.

Do not claim full-vault absence from a scoped search result; record the scope and widen only when the question requires it.

## Search Scope

Do not treat old collection names or search indexes as live interfaces. Select the canonical directory from `brain-map.md`, then search only that directory and any explicitly justified neighboring source. Use `obsidian-cli search-content` for vault content or `rg` for exact words, identifiers, and filenames. Open candidate files and cite their canonical paths. For history, search only the relevant `LOCAL-LARGE-FILES/agent-context/` subdirectory.

## Personal Ops

For tasks, commitments, reminders, and current priority state:

1. Read `00-INBOX/todo-backlog.md`.
2. Then inspect relevant `01-PERSONAL-OPS/` views.
3. Use raw channel logs only to recover original wording or history.

Do not remove or archive personal items unless ZeYu explicitly says they are done or can be archived.

## Project Context

For a project:

1. Search the exact project name within the relevant Brain directory.
2. Inspect `05-PROJECTS/<project>/`.
3. Look for `INDEX.md`, `README.md`, `plans/`, `docs/`, `decisions/`, `raw-context/`, or similarly named local conventions.
4. If context is missing, search the bounded `LOCAL-LARGE-FILES/agent-context/` path with filesystem tools and mark it as evidence, not current truth.

## Write Boundary

This playbook is for retrieval. If the task requires writing, moving, renaming, archiving, or changing Brain structure, load `zeyu-ai-brain-sop` before acting.
