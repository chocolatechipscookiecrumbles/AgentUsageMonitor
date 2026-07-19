#!/bin/zsh
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
app="${1:-$root/.build/CodexUsageMonitor.app}"

for resource in codex-agent.png claude-code-agent.png; do
  path="$app/Contents/Resources/$resource"
  if [[ ! -f "$path" ]]; then
    print -u2 "missing signed-app resource: $path"
    exit 1
  fi
done

print "signed-app agent resources present"
