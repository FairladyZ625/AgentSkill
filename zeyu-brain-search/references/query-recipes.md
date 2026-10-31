# Query Recipes

Replace quoted text with the user's actual topic.

## Search Scope

Choose the narrowest canonical scope before searching:

```bash
find /Users/lizeyu/Brain/05-PROJECTS -maxdepth 2 -type d | sort
find /Users/lizeyu/Brain/01-PERSONAL-OPS -maxdepth 2 -type d | sort
```

## Exact Keyword

```bash
rg -n "todo-backlog|OpenClaw|DL-20260401-01" /Users/lizeyu/Brain/00-INBOX /Users/lizeyu/Brain/05-PROJECTS
```

## Vault Content Search

```bash
obsidian-cli search-content "Agora current status" --vault ZeYu-AI-Brain
```

## Entity / Relationship Search

Start from the Agent Graph entry for the person, project, task, or decision, then open the linked canonical notes and verify their current state.

## Open a Source

```bash
read /Users/lizeyu/Brain/00-INBOX/todo-backlog.md
```

## Inspect Multiple Notes

```bash
rg -l "pattern" /Users/lizeyu/Brain/05-PROJECTS/agora | sort
```

## Empty-Result Rule

Report the searched scope and treat no hits as inconclusive outside that scope. Widen the search only when the question requires it; never convert a scoped miss into a claim that the Brain contains no such information.

## Voice Input Corrections

If a query looks like speech-to-text output, check:

```text
/Users/lizeyu/Brain/glossary.md
```

Examples:

- "阿格拉" usually means "Agora".
- "欧本 claw" usually means "OpenClaw".
- "欧比" usually means "Obsidian".
- "排气" in task context usually means "排期".
