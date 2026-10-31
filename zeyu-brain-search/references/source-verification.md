# Source Verification

## Reliability Order

For current state, prefer:

1. Dedicated source-of-truth files.
2. Current project notes and maintained indexes.
3. Recent plans or reviews.
4. Raw channel logs and agent context.
5. Search snippets.

Search snippets are never enough for final claims.

## Current State vs History

Use current-state notes for "what is true now".

Use raw logs for:

- original wording
- timeline reconstruction
- why a decision changed
- recovering context missing from formal notes

Do not treat old logs as current state unless no newer source exists.

## Required Confirmation Patterns

For todos and personal commitments:

- Confirm against `00-INBOX/todo-backlog.md`.
- If a derived view conflicts with backlog, say so and prefer backlog.

For projects:

- Confirm against `05-PROJECTS/<project>/` when available.
- If only raw context exists, state that it is historical evidence.

For decisions:

- Look for decision logs, ADRs, dated plans, or review notes.
- Include the date when the date affects interpretation.

For people:

- Search exact Chinese name and likely speech-to-text variants.
- Check `02-PEOPLE-NETWORK/` first when relationship context matters.

## Answering Standard

When answering from Brain, include enough source context for the next agent to verify:

```text
I found the current source in:
- /Users/lizeyu/Brain/00-INBOX/todo-backlog.md

The historical evidence is in:
- /Users/lizeyu/Brain/LOCAL-LARGE-FILES/agent-context/...
```

If evidence is partial:

```text
I found evidence for X, but I did not find a current-state note confirming Y.
```

## Escalate To Other Skills

- Need to write, move, rename, archive, or govern Brain files: load `zeyu-ai-brain-sop`.
- Need to ingest an external article into Brain: load `knowledge-ingest`.
- Need to manage personal todos or reminders: load `personal-ops-driver`.
- Need to mine conversation logs into knowledge: load `conversation-knowledge-flywheel` or `conversation-mining`.
