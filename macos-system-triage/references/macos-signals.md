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

## Error Snippets

- `UNIX error exception: 24`: `EMFILE`, too many open files. If seen in `syspolicyd`, suspect an app/code assessment loop or stale daemon state. Remove/quit the trigger, then reboot if it persists.
- `Failed to generate SecStaticCode for <private> error: 100024`: `syspolicyd` failed while constructing a code object for assessment. Paths are often privacy-redacted; correlate by time with launches, updates, logs, and CPU spikes.
- `MacOS error: -67014`: code-signing/security evaluation failure context. Do not overclaim exact root cause from this alone; correlate with `SecStaticCode`, `trustd`, and recent app changes.
- `SecKeyVerifySignature`: `trustd` verifying signatures. Bursts are normal; continuous spam with high CPU is not.
- `Clearing datagram buffer` or `failed to act on a ping`: WindowServer clients are not responding fast enough. Map the listed PIDs with `ps -p`.
- `Failed to mark layers as volatile`: WebKit layer/resource cleanup struggled; check WebView apps and their GPU/WebContent helpers.

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
