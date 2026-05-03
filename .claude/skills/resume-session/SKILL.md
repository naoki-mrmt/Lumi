# resume-session

保存されたセッションを復元する。前回の作業コンテキストを読み込み、続きから作業を再開する。

## Trigger
- `/resume-session` で最新セッションを復元
- `/resume-session <file>` で特定セッションを復元

## Input
- セッションファイルパス (省略時は最新)

## Output
- セッションコンテキストの復元
- 次にやるべきことのサマリー
