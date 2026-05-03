#!/bin/bash
# PostToolUse hook: remind about tests when modifying source files
# Receives JSON on stdin with tool_input containing file_path

input=$(cat)
file_path=$(echo "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')

# Only trigger for Swift source files, not test files or config
if echo "$file_path" | grep -qE '\.swift$' && ! echo "$file_path" | grep -qiE '(test|spec|config|Info\.plist)'; then
  if echo "$file_path" | grep -qE '(Packages/CalameKit/|App/)'; then
    echo "TDD: テストは先に書きましたか？"
  fi
fi

exit 0
