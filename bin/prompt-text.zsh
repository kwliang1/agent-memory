# Sourced by the UserPromptSubmit hooks. Prints the part of a prompt that states the request,
# or returns 1 when the prompt is system or session traffic.
human_prompt() {
  local text=$1
  # Hydra tags the requested task with <request>; nothing else in a hydra prompt counts. Read
  # first, because a request may quote any marker the filters below look for.
  if [[ $text == '<hydra-prompt>'$'\n'* ]]; then
    text=$(print -r -- "$text" | perl -0ne 'print join "\n\n", /<request>(.*?)<\/request>/gs')
    [ -n "$text" ] || return 1
    print -r -- "$text"
    return
  fi
  # A prompt is not always a person. Task notifications, spawn and relay lines, and
  # messages from other sessions arrive through this same event and made up 16 of 40
  # sampled injections.
  case $text in
    (*'<task-notification>'*|*'<cross-session-message'*|*'<agent-message'*|'[Cross-session '*) return 1 ;;
  esac
  [[ $text =~ '<channel [^>]*user_id="(system|session)"' ]] && return 1
  # The bridge envelope carries user="Kevin Liang" on every message, and `user` is a
  # concept: it injected User and UserPolicy into almost every session.
  text=$(print -r -- "$text" | perl -0pe 's{<system-reminder>.*?</system-reminder>}{}gs; s{</?channel\b[^>]*>}{}g; s{\A\s+}{}')
  [[ $text == '[system]'* ]] && return 1
  print -r -- "$text"
}
