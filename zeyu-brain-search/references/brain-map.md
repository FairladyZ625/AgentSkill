# Brain Map

Brain root:

```text
/Users/lizeyu/Brain
```

Use this map to choose where to search first. Actual structure may evolve, so verify with `find` when placement or freshness matters.

## Primary Areas

- `00-INBOX/`: intake, todo backlog, temporary notes. Start here for personal tasks and open commitments.
- `01-PERSONAL-OPS/`: personal operations, daily briefs, plans, followups, retros, agent plans, context views.
- `02-PEOPLE-NETWORK/`: people, relationship context, names, roles, contact-related notes.
- `03-KNOWLEDGE/`: durable knowledge notes, domains, reading-derived knowledge, engineering knowledge.
- `04-SYSTEM/`: system configuration, prompts, agent instructions, automation prompts.
- `05-PROJECTS/`: project context. Each significant project should have its own folder.
- `06-PERSONAL-DOCS/`: personal documents, memoir, reading outputs, identity-related material.
- `07-WORK-DOCS/`: work documents, external deliverables, company materials.
- `09-ARCHIVE/`: archived material.
- `08-SCREEN-MEMORY/`: daily screen memory, written by the service, per machine.
- `99-ATTACHMENTS/`: attachments used by notes.
- `ibooks-highlights/`: raw Apple Books highlight imports.
- `scripts/`: Brain-local scripts and automation.
- `templates/`: note templates.

## Local Large Files

- `LOCAL-LARGE-FILES/agent-context/`: raw channel logs, process context, observer/lint outputs, historical agent records. Use as evidence when current notes do not explain why something changed.
- `LOCAL-LARGE-FILES/knowledge-sources/`: raw external-source capture assets such as HTML, screenshots, PDFs, OCR outputs, and debug files.

## Common Starting Points

- Personal todo truth source: `00-INBOX/todo-backlog.md`
- Personal ops derived views: `01-PERSONAL-OPS/`
- Agent governance and process plans: `01-PERSONAL-OPS/06-AGENT-PLANS/`
- Project index and project folders: `05-PROJECTS/`
- Agora project context: `05-PROJECTS/agora/`
- Brain OS project context: `05-PROJECTS/obsidian-brain-os/`

## When In Doubt

Classify the target, choose its canonical directory or index, then run a bounded keyword search with `obsidian-cli search-content` or `rg`. Open candidate notes before using them. If nothing matches, state the searched scope; do not claim that the information does not exist elsewhere.
