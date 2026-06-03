---
name: macos-system-triage
description: Diagnose and stabilize slow or overloaded macOS systems. Use when a user reports a Mac is sluggish, frozen after a crash or reboot, has high load average, high WindowServer, Spotlight/mds_stores indexing, syspolicyd/trustd Gatekeeper loops, OCR/screenshot daemons, external display pressure, runaway menu-bar apps, or wants safe next actions before rebooting, killing processes, rebuilding indexes, or deleting caches.
---

# macOS System Triage

Use this skill to turn a vague "my Mac is slow" report into a small set of evidence-backed causes and safe next actions. Prefer read-only observation first. Do not disable security features, delete system databases, clear caches, unload LaunchAgents, or kill user processes unless the user explicitly approves that specific action.

## Workflow

1. Establish the current state.
   - Run `scripts/collect_macos_triage.sh --minutes 5` when local shell access is available.
   - If the user names a large vault or workspace, pass it as `--vault /path/to/dir` to collect file counts, heavy generated subtrees, and local ignore settings.
   - If the machine is extremely slow, run narrower commands first: `uptime`, `ps -axo pid,ppid,user,stat,%cpu,%mem,rss,etime,command | sort -nrk5 | head -30`, and `vm_stat | head -8`.
   - Compare current CPU, memory pressure, load average, Spotlight status, display count, recent diagnostic reports, and key daemon logs.
2. Classify the dominant bottleneck.
   - CPU/rendering: `WindowServer`, browser GPU/WebContent, Electron apps, menu-bar apps, remote-control/display tools.
   - Security verification: `syspolicyd`, `trustd`, `SecKeyVerifySignature`, `SecStaticCode`, `UNIX error exception: 24`, `MacOS error: -67014`.
   - Indexing/search: `mds`, `mds_stores`, `mdworker_shared`, `mdutil -a -s`.
   - Extension/startup residue: `systemextensionsctl list`, `sfltool dumpbtm`, LaunchAgents/LaunchDaemons, especially `activated waiting for user` or helpers whose executable no longer exists.
   - File/cloud churn: `fileproviderd`, `bird`, `cloudd`, huge DiagnosticReports, high disk writes.
   - Large vault/workspace churn: Obsidian vaults, Git metadata, virtual environments, generated caches, package managers, or local memory indexes.
   - Agent/OCR capture: screenshot services, OCR processes, VLM workers, log retention or data-growth loops.
3. Form 3 to 5 falsifiable hypotheses.
   - Example: "If a WebView menu-bar app is causing WindowServer load, then quitting it and its helper processes should drop WindowServer within 30-90 seconds."
   - Example: "If Spotlight is the bottleneck, then `mds_stores` or `mdworker_shared` should be hot and `mdutil -a -s` should show enabled indexing on large or external volumes."
   - Example: "If a stale Network Extension is causing security churn, then `systemextensionsctl list` should show a third-party extension in `activated waiting for user`, and removing its host app/user containers should not fully clear it until the extension is removed in System Settings or by the vendor app."
   - Example: "If a large vault is amplifying scan load, then file counts should concentrate in generated subtrees such as `.git`, `.venv`, `node_modules`, `.smart-env`, or `__pycache__`, and excluding those trees should reduce Obsidian/Spotlight churn after restart."
4. Test one variable at a time.
   - Prefer quitting the suspected user app over killing system daemons.
   - After each change, wait 30-90 seconds and re-run the same `ps`/`uptime` snapshot.
   - Treat a partial drop as useful evidence, not complete resolution.
5. Recommend the least risky recovery.
   - Reboot when system daemons show stale or exhausted state, especially `UNIX error exception: 24`, repeated `SecStaticCode` failures, or persistent high `syspolicyd/trustd` after the triggering app is gone.
   - Use Safe Mode when the issue returns after reboot and a third-party startup item, display utility, menu-bar app, or extension is suspected.
   - For Spotlight, disable or rebuild indexing only for the specific volume after confirming it is the bottleneck.
   - For large vaults, isolate generated subtrees before deleting anything: add app-level ignore filters, add `.metadata_never_index` sentinel files, or move caches/virtualenvs outside the vault.
   - For System Extensions, prefer the vendor app or System Settings > General > Login Items & Extensions. Do not `rm -rf /Library/SystemExtensions/...` as a first-line fix.

## Command Policy

Safe read-only commands:

```bash
uptime
vm_stat | head -8
ps -axo pid,ppid,user,stat,%cpu,%mem,rss,etime,command | sort -nrk5 | head -30
mdutil -a -s
system_profiler SPDisplaysDataType
systemextensionsctl list
sfltool dumpbtm
scutil --proxy
log show --last 5m --style compact --predicate 'process == "syspolicyd" OR process == "trustd" OR process == "WindowServer"'
ls -lt ~/Library/Logs/DiagnosticReports /Library/Logs/DiagnosticReports 2>/dev/null | head -80
lsof -nP -iTCP:<port> -sTCP:LISTEN,ESTABLISHED
```

Ask before running:

- `kill`, `pkill`, `launchctl kickstart`, `launchctl bootout`, `mdutil -i off`, `mdutil -E`, `systemextensionsctl uninstall`, `spctl`, `xattr -d`, cache deletion, trust database deletion, app uninstall, or anything requiring `sudo`.
- Continuous tools such as `log stream`, `fs_usage`, `opensnoop`, `powermetrics`, or `pmset -g thermlog`; if used, run for a bounded interval and stop the session.

Do not recommend disabling Gatekeeper or SIP as a routine fix. If a web article suggests deleting trust databases or disabling security controls, present it as high-risk and prefer reboot, Safe Mode, app isolation, or vendor update first.

## Interpretation Notes

Read `references/macos-signals.md` when interpreting error codes, DiagnosticReports, or process clusters.

Practical rules:

- `WindowServer` high after multiple 4K displays can be normal-ish under motion, but persistent 50-100% on one display usually means a GUI client, WebView, GPU process, screen recording, display utility, or stuck window/layer.
- DiagnosticReports lines like `On Behalf Of: <app>` are strong evidence that the app caused WindowServer work.
- `UNIX error exception: 24` means file descriptor exhaustion; when paired with `syspolicyd`/`trustd`, a reboot is often the cleanest recovery after removing the triggering app.
- `mds_stores` near zero means Spotlight is probably not the current bottleneck even if indexing is enabled.
- A killed or uninstalled app can leave helper processes alive. Confirm with `ps`, `lsof`, and relevant port checks before deciding the test failed.
- `activated waiting for user` in `systemextensionsctl list` is a strong stale-extension signal. Removing the host app and user containers may be useful cleanup, but system extension registration usually needs System Settings, the vendor app, or a reboot-managed OS flow.
- `Too many open files` in `spctl` or `syspolicyd` can be a symptom of security assessment storms. Check system proxy/PAC settings because Apple validation or CloudKit timeouts can amplify retries.
- A large Obsidian vault is not automatically the cause. Confirm whether any process has many files open under it (`lsof | rg /path`) and whether file counts are concentrated in generated directories before recommending deletion.

## Output Style

Report in this order:

1. Current top causes, ranked by evidence.
2. What changed since the last snapshot.
3. The next safest action and why.
4. Any action that needs explicit user approval.

Keep user-facing output concrete: include process names, CPU percentages, error snippets, exact volumes, and whether the finding is confirmed or only a hypothesis.
