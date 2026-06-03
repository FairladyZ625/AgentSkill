# macOS Triage Signals

## Key Processes

| Process | What it usually means | Useful checks |
| --- | --- | --- |
| `WindowServer` | Display compositing, windows, Spaces, screen recording, external displays, GUI clients | DiagnosticReports `On Behalf Of`, `system_profiler SPDisplaysDataType`, browser/Electron GPU processes, display utilities |
| `syspolicyd` | Gatekeeper and system policy assessment for apps/code | `log show` for `SecStaticCode`, `spctl` only with approval, recent installs/updates |
| `trustd` | Certificate and trust evaluation | `SecKeyVerifySignature`, `SecTrust`, `valid.sqlite3` writes, often caused by `syspolicyd` |
| `mds_stores` | Spotlight metadata index database | `mdutil -a -s`, external volumes, recent mass file churn |
| `mdworker_shared` | Spotlight workers scanning files | Same as Spotlight plus file type causing churn |
| `fileproviderd`, `bird`, `cloudd` | iCloud/File Provider sync churn | DiagnosticReports, recent cloud folders, disk writes |
| Browser/Electron GPU or WebContent | Web UI rendering and compositing | Match parent app, tabs, WebView apps, menu-bar widgets |
| OCR/Vision workers | Screen capture, Live Text, screenshot or local memory services | capture service logs, retention size, process CPU |

## Extension and Startup Residue

Use:

```bash
systemextensionsctl list
sfltool dumpbtm | rg -i 'vendor|bundle|app'
find /Library/LaunchAgents /Library/LaunchDaemons ~/Library/LaunchAgents -maxdepth 1 -type f | rg -i 'vendor|bundle|app'
launchctl print system | rg -i 'vendor|bundle|app' -C 2
launchctl print gui/$(id -u) | rg -i 'vendor|bundle|app' -C 2
```

High-signal states:

- `activated enabled`: expected for an active extension.
- `activated disabled`: usually old version or disabled residue; cleanup candidate, not proof of current load.
- `activated waiting for user`: stale or half-approved extension. Treat as suspicious when paired with `syspolicyd`, `trustd`, VPN/proxy symptoms, or recent app removal.
- LaunchDaemon/LaunchAgent plist points to a missing executable: stale helper. Remove only after confirming it belongs to the uninstalled app.

System Extension cleanup:

1. Identify the host app and Team ID from `systemextensionsctl list`.
2. Look for the app under `/Applications`, `~/Applications`, and user containers.
3. If the app has an uninstaller or UI to remove the extension, use that first.
4. Otherwise use System Settings > General > Login Items & Extensions > Network Extensions or Driver Extensions.
5. Avoid manually deleting `/Library/SystemExtensions/...`; macOS keeps registration state outside that folder.
6. `systemextensionsctl uninstall TEAMID bundle.id` can be blocked by SIP on normal machines. Do not recommend disabling SIP just to clean routine residue.

## Error Snippets

- `UNIX error exception: 24`: `EMFILE`, too many open files. If seen in `syspolicyd`, suspect an app/code assessment loop or stale daemon state. Remove/quit the trigger, then reboot if it persists.
- `Failed to generate SecStaticCode for <private> error: 100024`: `syspolicyd` failed while constructing a code object for assessment. Paths are often privacy-redacted; correlate by time with launches, updates, logs, and CPU spikes.
- `MacOS error: -67014`: code-signing/security evaluation failure context. Do not overclaim exact root cause from this alone; correlate with `SecStaticCode`, `trustd`, and recent app changes.
- `SecKeyVerifySignature`: `trustd` verifying signatures. Bursts are normal; continuous spam with high CPU is not.
- `Clearing datagram buffer` or `failed to act on a ping`: WindowServer clients are not responding fast enough. Map the listed PIDs with `ps -p`.
- `Failed to mark layers as volatile`: WebKit layer/resource cleanup struggled; check WebView apps and their GPU/WebContent helpers.
- `Too many open files` from `spctl` or `syspolicyd`: the security assessment path is resource constrained. Check current file descriptor pressure, startup storms, stale extensions, and proxy/PAC timeouts before blaming environment variables.

## Large Vaults and Generated Subtrees

Large workspaces do not cause `Too many open files` by existing; they cause pressure when an app, indexer, sync engine, or watcher scans them.

Useful checks:

```bash
find /path/to/vault -xdev -type f 2>/dev/null | wc -l
find /path/to/vault -xdev -type d 2>/dev/null | wc -l
find /path/to/vault -xdev -type f 2>/dev/null | sed 's|/[^/]*$||' | sort | uniq -c | sort -nr | head -30
lsof -nP 2>/dev/null | rg '/path/to/vault' | awk '{c[$1]++} END {for (p in c) print c[p], p}' | sort -nr | head
```

Common generated-heavy trees:

- `.git/`
- `node_modules/`
- `.venv/`, `venv/`
- `.smart-env/`, local agent-memory caches, vector indexes
- `__pycache__/`
- build outputs such as `dist/`, `.next/`, `coverage/`

Isolation ladder:

1. Add app-level ignore filters first. For Obsidian, edit `.obsidian/app.json` `userIgnoreFilters`.
2. Add `.metadata_never_index` inside generated subtrees to discourage Spotlight indexing.
3. Move caches, virtual environments, and generated indexes outside the vault/workspace.
4. Disable Spotlight indexing for the specific volume or folder only after proving Spotlight is hot.
5. Delete generated data only when the owner and regeneration path are known.

Obsidian ignore examples:

```json
[
  ".git/",
  "node_modules/",
  ".smart-env/",
  "openkb-sandbox/.venv/",
  "**/__pycache__/"
]
```

Restart Obsidian after changing ignore filters.

## Proxy and Security Validation

When `syspolicyd` shows CloudKit or validation timeouts, check:

```bash
scutil --proxy
ps axww -o pid,ppid,stat,%cpu,%mem,etime,command | rg -i 'clash|proxy|vpn|tunnel|tailscale'
```

PAC or localhost proxy settings can make Apple validation requests time out and retry. Test by temporarily disabling the proxy only with user approval, then compare `syspolicyd` and `trustd` CPU after 30-90 seconds.

## DiagnosticReports

Use:

```bash
ls -lt ~/Library/Logs/DiagnosticReports /Library/Logs/DiagnosticReports 2>/dev/null | head -80
sed -n '1,180p' /path/to/report.diag
```

High-signal fields:

- `Event`: `cpu usage`, `disk writes`, `userspace_watchdog_timeout`, `shutdown_stall`.
- `On Behalf Of`: client app that caused system work.
- `Heaviest stack`: render, SQLite, network, trust, file provider, or GPU paths.
- `Footprint`: memory growth during the report.

## Recovery Ladder

1. Quit the suspected user app or disable the suspected app feature.
2. Clean up app helper processes only after confirming the app is gone and the helper belongs to it.
3. Reboot when system daemons stay hot with exhausted/stale state.
4. Use Safe Mode if the issue returns after reboot.
5. Update, reinstall, or remove the offending third-party app.
6. Treat trust database deletion, Gatekeeper changes, SIP changes, and broad cache deletion as last-resort operations requiring explicit user approval and backups.
