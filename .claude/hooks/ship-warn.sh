#!/bin/bash
# On-demand hook for /ship: warn about manual git operations outside workflow
input=$(cat)
command=$(echo "$input" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')

# Only warn, don't block (exit 0) - the ship skill manages git operations itself
if echo "$command" | grep -qE "git (push|commit)" 2>/dev/null; then
  echo "/ship ワークフロー内です。手動の git 操作は Step に従ってください。"
fi
exit 0
