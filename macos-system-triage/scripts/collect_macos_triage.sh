#!/usr/bin/env bash
set -euo pipefail

MINUTES=5
OUT=""

usage() {
  cat <<'USAGE'
Usage: collect_macos_triage.sh [--minutes N] [--out FILE]

Collect a read-only macOS slowdown triage snapshot. The script does not use
sudo, kill processes, delete files, change Spotlight settings, or stream logs.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --minutes)
      MINUTES="${2:?missing value for --minutes}"
      shift 2
      ;;
    --out)
      OUT="${2:?missing value for --out}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$MINUTES" =~ ^[0-9]+$ ]] || [[ "$MINUTES" -lt 1 || "$MINUTES" -gt 60 ]]; then
  echo "--minutes must be an integer from 1 to 60" >&2
  exit 2
fi

run() {
  local title="$1"
  shift
  printf '\n## %s\n\n' "$title"
  "$@" 2>&1 || true
}

collect() {
  printf '# macOS Triage Snapshot\n\n'
  date
  sw_vers 2>/dev/null || true

  run "Load" uptime
  run "Memory" sh -c 'vm_stat | head -12'
  run "Top CPU Processes" sh -c 'ps -axo pid,ppid,user,stat,%cpu,%mem,rss,etime,command | sort -nrk5 | head -35'
  run "Focused Processes" sh -c 'ps -axo pid,ppid,user,stat,%cpu,%mem,rss,etime,command | awk '\''/WindowServer|syspolicyd|trustd|mds_stores|mdworker|fileproviderd|bird|cloudd|OCR|Vision|UURemote|BetterDisplay|WebKit|Google Chrome Helper|Electron|Codex|Discord|DingTalk/ && !/awk/'\'''
  run "Spotlight Status" mdutil -a -s
  run "Displays" system_profiler SPDisplaysDataType
  run "Recent Diagnostic Reports" sh -c 'ls -lt "$HOME/Library/Logs/DiagnosticReports" /Library/Logs/DiagnosticReports 2>/dev/null | head -80'
  run "System Policy Logs" sh -c 'log show --last "$1"m --style compact --predicate '\''process == "syspolicyd" OR process == "trustd" OR process == "WindowServer"'\'' 2>/dev/null | tail -240' sh "$MINUTES"
}

if [[ -n "$OUT" ]]; then
  mkdir -p "$(dirname "$OUT")"
  collect > "$OUT"
  printf 'Wrote %s\n' "$OUT"
else
  collect
fi
