---
name: pane-dim-prompt-suggestion
description: Text after `❯` in a pane's input box can be Claude Code's dim prompt suggestion, not an undelivered message
metadata:
  type: reference
---
`❯ text` in a tmux pane's input box can be Claude Code's prompt suggestion, rendered dim (`ESC[2m`), rather than a message that failed to submit. Check `tmux capture-pane -e` for the dim escape before "submitting" it, or you send a message nobody wrote.
