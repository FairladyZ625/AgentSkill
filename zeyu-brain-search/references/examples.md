# Examples

## Find Current Personal Commitments

Read `00-INBOX/todo-backlog.md` directly; use the directory map and scoped keyword search only if a specific item needs locating.

Then search for related project or person names if the backlog item needs context.

## Find A Project's Context

```bash
rg -n -i "Agora" /Users/lizeyu/Brain/05-PROJECTS/agora
```

If the project folder is sparse:

Search a bounded `LOCAL-LARGE-FILES/agent-context/` subdirectory only when historical evidence is needed, and treat it as evidence rather than current truth.

## Find A Rule Or Convention

```bash
rg -n "正式计划不得长期只放 workspace" /Users/lizeyu/Brain/04-SYSTEM /Users/lizeyu/Brain/01-PERSONAL-OPS
```

Open the resulting note and answer from the original text.

## Find Something From Speech-To-Text

User says "欧本 claw 网关重启规则".

1. Check glossary if needed.
2. Interpret as "OpenClaw gateway restart rules".
3. Search:

```bash
rg -n -i "gateway restart|gateway-restart-rules" /Users/lizeyu/Brain/05-PROJECTS/openclaw /Users/lizeyu/.hermes/profiles/main/workspace/references
```

## Verify A Decision

```bash
rg -n "DL-20260401-01" /Users/lizeyu/Brain/01-PERSONAL-OPS
```

Open the decision source before summarizing.
