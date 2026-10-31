#!/usr/bin/env bash
set -euo pipefail

BRAIN_ROOT="${BRAIN_ROOT:-/Users/lizeyu/Brain}"

usage() {
  cat <<'EOF'
Usage:
  brain-search.sh search <relative-directory> "keyword"
  brain-search.sh search 05-PROJECTS/agora "decision"
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

cmd="$1"
shift

case "$cmd" in
  search)
    if [[ $# -lt 2 ]]; then
      usage
      exit 2
    fi
    relative_scope="$1"
    if [[ "$relative_scope" = /* ]]; then
      echo "Scope must be relative to Brain root" >&2
      exit 2
    fi
    scope="$BRAIN_ROOT/$relative_scope"
    shift
    if [[ ! -d "$scope" ]]; then
      echo "Not a directory: $scope" >&2
      exit 2
    fi
    set +e
    rg -n -i --hidden --glob '!LOCAL-LARGE-FILES/**' -- "$*" "$scope"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 ]]; then
      exit 0
    fi
    if [[ "$rc" -eq 1 ]]; then
      echo "No matches in searched scope: $relative_scope" >&2
      exit 0
    fi
    exit "$rc"
    ;;
  *)
    usage
    exit 2
    ;;
esac
