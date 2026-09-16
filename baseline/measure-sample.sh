#!/bin/zsh
set -uo pipefail
P=/Users/kevin/.claude/projects
print "session\tscope\tsrc\tctx_at_start\tans_chars\tcites_file\tcites_pr\tcites_prior\tprompt"
while IFS=$'\t' read -r sess scope idx src chars prompt; do
  f=$(find "$P" -name "${sess}.jsonl" -print -quit 2>/dev/null)
  [ -n "$f" ] || continue
  jq -rs --arg sess "$sess" --arg scope "$scope" --arg src "$src" --arg idx "$idx" --arg p "$prompt" '
    [ .[] | select((.type=="user" and (.message.content|type=="string")) or .type=="assistant") ] as $seq
    | [ $seq | to_entries[] | select(.value.type=="user") | .key ] as $uk
    | ($uk[($idx|tonumber)] // -1) as $k
    | ($uk[(($idx|tonumber)+1)] // ($seq|length)) as $next
    | (if $k < 0 then "" else
        ([ $seq[($k+1):$next][] | select(.type=="assistant")
           | (.message.content // []) | map(select(.type=="text").text // "") | join(" ") ] | join(" "))
       end) as $ans
    | ($seq | map(select(.type=="assistant" and .message.usage!=null)) | .[0].message.usage) as $u0
    | [ $sess, $scope, $src,
        (($u0.input_tokens//0)+($u0.cache_read_input_tokens//0)+($u0.cache_creation_input_tokens//0)),
        ($ans|length),
        (if ($ans|test("[A-Za-z_/.-]+\\.(rb|ts|tsx|sql|mjs|sh):[0-9]+")) then 1 else 0 end),
        (if ($ans|test("#[0-9]{3,5}\\b")) then 1 else 0 end),
        (if ($ans|test("(?i)(memory|previously|earlier decision|prior|we decided|as noted|last time)")) then 1 else 0 end),
        $p ] | @tsv
  ' "$f" 2>/dev/null
done
