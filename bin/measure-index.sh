#!/bin/zsh
# Reproduces the index figures in DESIGN.md. Measurement only — nothing reads its output.
# Usage: measure-index.sh [scopes-dir] [out-tsv] [--naive]
set -uo pipefail
setopt extended_glob null_glob

naive=0
args=()
for a in "$@"; do
  [ "$a" = "--naive" ] && { naive=1; continue; }
  args+=("$a")
done

here=${0:A:h}
scopes=${args[1]:-${here:h}/scopes}
out=${args[2]:-${TMPDIR:-/tmp}/memory-index.tsv}

[ -d "$scopes" ] || { print -u2 "not a directory: ${scopes:-<empty>}"; exit 1; }
cd "$scopes" || exit 1

if [ "$naive" -eq 1 ]; then
  files=(**/*.md(.))
else
  files=(**/*.md~(*/|)MEMORY.md(.))
fi
[ ${#files[@]} -gt 0 ] || { print -u2 "no markdown under $scopes"; exit 1; }

: > "$out"
for f in "${files[@]}"; do
  export rel="$f"
  perl -nE '
    while (/\b(BANK|NOVA|INC|USVC|SEC|WALLET|OP|TER|N)-[0-9]{2,5}\b/g) { say $&; }
    while (/(?<![A-Za-z0-9_#])#[0-9]{3,6}\b/g)          { say $&; }
    while (/\bCA[-# ][0-9]{4,8}\b/g)                     { say $&; }
    while (m{\b[a-z0-9_]+(?:/[a-z0-9_]+)*\.(?:rb|ts|tsx|erb)\b}g) { say $&; }
  ' "$f" 2>/dev/null | sort -u \
    | awk 'NF{printf "%s\t%s\n", $0, ENVIRON["rel"]}' >> "$out"
done

postings=$(wc -l < "$out" | tr -d ' ')
keys=$(cut -f1 "$out" | sort -u | wc -l | tr -d ' ')
bytes=$(wc -c < "$out" | tr -d ' ')

printf 'files indexed   %s%s\n' "${#files[@]}" "$([ "$naive" -eq 1 ] && echo '  (naive: MEMORY.md included)')"
printf 'postings        %s\n' "$postings"
printf 'distinct keys   %s\n' "$keys"
printf 'index bytes     %s (%s KiB)\n' "$bytes" "$((bytes / 1024))"

cut -f1 "$out" | sort | uniq -c | awk '{print $1}' | sort -n | awk '
  {a[NR]=$1; s+=$1}
  END{
    if (NR == 0) { print "fan-out         (no keys)"; exit }
    med = a[int((NR+1)/2)]
    p90 = a[NR<2 ? 1 : int((NR*9+9)/10)]
    printf "fan-out         median %d  mean %.1f  p90 %d  max %d\n", med, s/NR, p90, a[NR]
  }'
printf 'keys <=3 files  %s\n' "$(cut -f1 "$out" | sort | uniq -c | awk '$1<=3' | wc -l | tr -d ' ')"

printf '\nkey classes\n'
for pat lbl in \
  '^(BANK|NOVA|INC|USVC|SEC|WALLET|OP|TER|N)-[0-9]+$' 'Linear IDs' \
  '^#[0-9]+$'                                          'PR numbers' \
  '^CA[-# ][0-9]+$'                                     'CA numbers' \
  '[.](rb|ts|tsx|erb)$'                                'code paths'
do
  printf '  %-12s %s\n' "$lbl" "$(cut -f1 "$out" | sort -u | grep -cE "$pat")"
done
