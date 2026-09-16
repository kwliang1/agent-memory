#!/bin/zsh
set -uo pipefail
P=/Users/kevin/.claude/projects
print "session\tscope\tidx\tsrc\tctx_at_start\tans_chars\tcites_file\tcites_pr\tcites_prior\tgradeable\trepeats\tprompt"
in_count=0
out_count=0
err_count=0
while IFS=$'\t' read -r sess scope idx src chars prompt; do
  ((in_count++))
  f=$(find "$P" -name "${sess}.jsonl" -print -quit 2>/dev/null)
  if [[ -z "$f" ]]; then
    print -u2 "measure-sample.sh: transcript not found: $sess"
    ((err_count++))
    continue
  fi
  result=$(jq -rs --arg sess "$sess" --arg scope "$scope" --arg src "$src" --arg idx "$idx" --arg p "$prompt" '
    def unwrap_prompt:
      if test("^<channel") then
        sub("^<channel[^>]*>\\s*";"") | sub("\\s*</channel>\\s*$";"")
      else . end
      | gsub("\\s+";" ") | .[0:200];

    def is_gradeable:
      (test("^\\[Image:") | not) and
      (test("^Another Claude session sent a message:") | not) and
      (test("^# Autonomous loop") | not) and
      (test("^The previous response failed") | not) and
      (test("^This session is being continued") | not) and
      (test("^Your claude") | not) and
      (test("^\\[\\d+ prior /loop") | not) and
      (test("^IMPORTANT: You are a") | not) and
      (test("^Output ONLY") | not) and
      (test("^Output token limit") | not) and
      (test("^MONITOR TASK") | not) and
      (test("SAFETY: You were recovered") | not) and
      (test("^\\(Re-invocation") | not) and
      (test("^Skill /") | not);

    def is_kevin_boundary:
      .message.content as $raw
      | if ($raw | test("^<channel[^>]*user=\"Kevin Liang\"")) then
          ($raw | sub("^<channel[^>]*>\\s*";"") | sub("\\s*</channel>\\s*$";"")) | is_gradeable
        elif ($raw | test("^<")) then false
        elif ($raw | test("^(You are |You just restarted|\\[system\\]|Caveat:|<command)")) then false
        else $raw | is_gradeable end;

    [ .[] | select((.type=="user" and (.message.content|type=="string")) or .type=="assistant") ] as $seq
    | [ $seq | to_entries[] | select(.value.type=="user") | .key ] as $uk
    | ($idx|tonumber) as $i
    | if $i < 0 or $i >= ($uk|length) then error("idx \($idx) out of range for \($sess)") else . end
    | ($uk[$i]) as $k
    | ([ $uk[] | select(. > $k) | select($seq[.] | is_kevin_boundary) ] | .[0] // ($seq|length)) as $next
    | ([ $seq[($k+1):$next][] | select(.type=="assistant")
         | (.message.content // []) | map(select(.type=="text") | .text) | join(" ")
         | select(length > 0) ] | join(" ")) as $ans
    | ($seq[$k].message.content | unwrap_prompt) as $derived
    | ([ $seq[] | select(.type=="assistant" and .message.usage!=null)
         | .message.usage
         | select((.input_tokens//0)+(.cache_read_input_tokens//0)+(.cache_creation_input_tokens//0) > 0)
       ] | .[0]) as $u0
    | ($seq[$k].message.content | unwrap_prompt) as $norm
    | ([$uk[] | select(($seq[.].message.content | unwrap_prompt) == $norm)] | length) as $repeats
    | [$sess, $scope, $idx, $src,
        (($u0.input_tokens//0)+($u0.cache_read_input_tokens//0)+($u0.cache_creation_input_tokens//0)),
        ($ans|length),
        (if ($ans|test("[A-Za-z_/.-]+\\.(rb|ts|tsx|sql|mjs|sh):[0-9]+|#L[0-9]+")) then 1 else 0 end),
        (if ($ans|test("#[0-9]{3,5}\\b")) then 1 else 0 end),
        (if ($ans|test("(?i)(previously|earlier decision|\\bprior\\b|we decided|as noted|last time)")) then 1 else 0 end),
        (if (($derived | is_gradeable) and $repeats < 3) then 1 else 0 end),
        $repeats,
        $derived ] | @tsv
  ' "$f")
  if [[ $? -ne 0 ]]; then
    print -u2 "measure-sample.sh: jq failed for $sess idx $idx"
    ((err_count++))
    continue
  fi
  if [[ -z "$result" ]]; then
    print -u2 "measure-sample.sh: no output for $sess idx $idx"
    ((err_count++))
    continue
  fi
  print -r -- "$result"
  ((out_count++))
done
if [[ $in_count -eq 0 ]]; then
  print -u2 "measure-sample.sh: empty input"
  exit 1
fi
if [[ $err_count -gt 0 ]]; then
  print -u2 "measure-sample.sh: $err_count of $in_count rows had errors"
  exit 1
fi
if [[ $in_count -ne $out_count ]]; then
  print -u2 "measure-sample.sh: produced $out_count of $in_count rows"
  exit 1
fi
