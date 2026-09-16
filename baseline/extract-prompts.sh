#!/bin/zsh
set -uo pipefail
P=/Users/kevin/.claude/projects
print "session\tscope\tidx\tsrc\tchars\tprompt"
find "$P" -name '[0-9a-f]*.jsonl' -size +2k -print0 2>/dev/null | while IFS= read -r -d '' f; do
  scope=${f:h:t}
  [[ "$scope" == "subagents" || "$scope" == wf_* ]] && continue
  jq -rs --arg scope "$scope" --arg sess "${f:t:r}" '
    [ .[] | select(.type=="user" and (.message.content|type=="string")) | .message.content ]
    | to_entries[]
    | .key as $i | .value as $raw
    # bridge message from Kevin -> unwrap; plain terminal prompt -> keep as-is
    | (if ($raw|test("^<channel[^>]*user=\"Kevin Liang\"")) then
         {src:"bridge", txt: ($raw | sub("^<channel[^>]*>\\s*";"") | sub("\\s*</channel>\\s*$";""))}
       elif ($raw|test("^<")) then empty
       elif ($raw|test("^(You are |You just restarted|\\[system\\]|Caveat:|<command)")) then empty
       else {src:"terminal", txt:$raw} end)
    | select((.txt|length) > 40)
    | select((.txt|test("^(ok|yes|no|thanks|sounds good|go|do it)\\.?$";"i")|not))
    | [$sess, $scope, ($i|tostring), .src, (.txt|length|tostring),
       (.txt | gsub("\\s+";" ") | .[0:200])] | @tsv
  ' "$f" 2>/dev/null
done
