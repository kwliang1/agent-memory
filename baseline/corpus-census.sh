#!/bin/zsh
set -uo pipefail
P=/Users/kevin/.claude/projects
print "session\tscope\tstart_ctx\tfirst_in\tfirst_cache_read\tprompts\tturns\tmtime"
find "$P" -name '[0-9a-f]*.jsonl' -size +2k -print0 2>/dev/null | while IFS= read -r -d '' f; do
  scope=${f:h:t}
  sess=${f:t:r}
  mt=$(stat -f %Sm -t %Y-%m-%d "$f" 2>/dev/null)
  jq -rs --arg scope "$scope" --arg sess "$sess" --arg mt "$mt" '
    (map(select(.type=="assistant" and (.message.usage != null))) | .[0].message.usage) as $u
    | (map(select(.type=="user" and (.message.content|type=="string"))) | length) as $prompts
    | select($prompts > 0)
    | [$sess, $scope,
       (($u.input_tokens//0)+($u.cache_read_input_tokens//0)+($u.cache_creation_input_tokens//0)),
       ($u.input_tokens//0), ($u.cache_read_input_tokens//0), $prompts,
       (map(select(.type=="assistant"))|length), $mt] | @tsv
  ' "$f" 2>/dev/null
done
