# Routing Playbook

## Task decomposition

For medium/complex coding tasks, split into:

1. Plan
2. Implement
3. Review
4. Summary

## Suggested routing

- Plan: Claude Opus (`claude-opus-4-6`)
- Backend implementation: Codex
- Frontend implementation: Claude Sonnet (`claude-sonnet-4-6`)
- Primary review: Claude (same model family as implementation owner)
- Secondary review + summary: Gemini

## Update format

Use this compact format for progress updates:

- Status: started / in-progress / blocked / done
- Owner: codex / claude / gemini
- Scope: short phrase
- Result: one-line output
- Next: one line

Example:

- Status: in-progress
- Owner: codex
- Scope: auth service refactor
- Result: DB transaction guard added; tests running
- Next: wait for test completion and hand off to claude for frontend wiring review
