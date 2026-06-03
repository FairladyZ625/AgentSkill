#!/usr/bin/env bash
set -euo pipefail

MINUTES=5
OUT=""
VAULT=""

usage() {
  cat <<'USAGE'
Usage: collect_macos_triage.sh [--minutes N] [--out FILE] [--vault PATH]

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
    --vault)
      VAULT="${2:?missing value for --vault}"
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

vault_snapshot() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    printf 'Vault path does not exist or is not a directory: %s\n' "$path"
    return 0
  fi

  printf 'Path: %s\n\n' "$path"
  printf 'File count: '
  find "$path" -xdev -type f 2>/dev/null | wc -l | tr -d ' '
  printf '\nDirectory count: '
  find "$path" -xdev -type d 2>/dev/null | wc -l | tr -d ' '
  printf '\n\nHeavy directories by file count:\n'
  find "$path" -xdev -type f 2>/dev/null \
    | sed 's|/[^/]*$||' \
    | sort \
    | uniq -c \
    | sort -nr \
    | head -30

  printf '\nGenerated subtree candidates:\n'
  find "$path" -xdev \( \
    -name .git -o \
    -name node_modules -o \
    -name .venv -o \
    -name venv -o \
    -name __pycache__ -o \
    -name .smart-env -o \
    -name .next -o \
    -name dist -o \
    -name coverage \
  \) -type d -prune -print 2>/dev/null | head -80

  if [[ -f "$path/.obsidian/app.json" ]]; then
    printf '\nObsidian app.json ignore hints:\n'
    grep -nE 'userIgnoreFilters|\.git|node_modules|\.venv|venv|\.smart-env|__pycache__|\.metadata_never_index' "$path/.obsidian/app.json" 2>/dev/null || true
  fi

  printf '\nProcesses with open files under path:\n'
  lsof -nP 2>/dev/null \
    | grep -F "$path" \
    | awk '{c[$1]++} END {for (p in c) print c[p], p}' \
    | sort -nr \
    | head -25
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
  run "System Extensions" systemextensionsctl list
  run "Proxy Settings" scutil --proxy
  run "Background Items" sh -c 'sfltool dumpbtm 2>/dev/null | grep -Ei "qianxin|secaccess|tailscale|karabiner|betterdisplay|uuremote|pathfinder|cocoatech|istat|bjango|codex|obsidian|discord|wechat|clash|proxy" -C 3 | head -260'
  run "Launch Items" sh -c 'find /Library/LaunchAgents /Library/LaunchDaemons "$HOME/Library/LaunchAgents" -maxdepth 1 -type f 2>/dev/null | grep -Ei "qianxin|secaccess|tailscale|karabiner|betterdisplay|uuremote|pathfinder|cocoatech|istat|bjango|codex|openclaw|obsidian|discord|wechat|clash|proxy"'
  run "File Descriptor Pressure" sh -c 'launchctl limit maxfiles; sysctl kern.num_files kern.maxfiles kern.maxfilesperproc; lsof -nP 2>/dev/null | awk '\''NR>1 {c[$1]++} END {for (p in c) print c[p], p}'\'' | sort -nr | head -25'
  run "Displays" system_profiler SPDisplaysDataType
  run "Recent Diagnostic Reports" sh -c 'ls -lt "$HOME/Library/Logs/DiagnosticReports" /Library/Logs/DiagnosticReports 2>/dev/null | head -80'
  run "System Policy Logs" sh -c 'log show --last "$1"m --style compact --predicate '\''process == "syspolicyd" OR process == "trustd" OR process == "WindowServer"'\'' 2>/dev/null | tail -240' sh "$MINUTES"

  if [[ -n "$VAULT" ]]; then
    run "Vault Snapshot" vault_snapshot "$VAULT"
  fi
}

if [[ -n "$OUT" ]]; then
  mkdir -p "$(dirname "$OUT")"
  collect > "$OUT"
  printf 'Wrote %s\n' "$OUT"
else
  collect
fi
