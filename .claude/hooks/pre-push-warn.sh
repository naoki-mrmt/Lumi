#!/bin/bash
# PreToolUse hook: warn before git push without review
# Receives JSON on stdin: {"tool_name": "Bash", "tool_input": {"command": "..."}}

input=$(cat)
command=$(echo "$input" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')

if echo "$command" | grep -q "git push"; then
  echo '{"decision": "block", "reason": "git push 検出。/review や /verify は実行済みですか？続行する場合は承認してください。"}'
  exit 2
fi

exit 0
