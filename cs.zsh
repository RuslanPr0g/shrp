# shrp - run C# instantly with dotnet's file-based apps (.NET 10+)
#
# Usage:
#   cs                              # interactive REPL (blank line runs, Ctrl-D/exit quits)
#   cs 'Console.WriteLine("hi");'   # inline snippet
#   echo 'code' | cs                # piped stdin
#   cs <<'EOF' ... EOF              # heredoc for multiline code
#   cs script.cs                    # run an existing .cs file
#   cs -p                           # non-interactive: print usage instead of the REPL
#   cs --smart                      # smart REPL: persistent variables + Tab completion
#   cs -h | --help                  # show help
#
# Snippets are written to a uniquely-named file in $TMPDIR (or /tmp) and
# left there — no cleanup, no deletion logic. The files are tiny and
# /tmp is typically tmpfs or swept on reboot, so deleting them isn't
# worth any risk of touching the wrong path.

# If code is a single line missing a trailing terminator, append ';' so
# 'Console.WriteLine("hi")' (forgotten semicolon) still runs. Left alone
# if it's already multi-line (contains a newline) — guessing where a
# semicolon belongs across statements isn't safe — or already ends with
# ';', '{', or '}'.
_cs_add_semicolon_if_missing() {
  emulate -L zsh
  local code="$1"
  if [[ "$code" == *$'\n'* ]]; then
    print -rn -- "$code"
    return
  fi
  while [[ "$code" == *[[:space:]] ]]; do
    code="${code%?}"
  done
  if [[ -n "$code" ]]; then
    case "$code" in
      *';'|*'{'|*'}') ;;
      *) code+=';' ;;
    esac
  fi
  print -rn -- "$code"
}

# Talks the sentinel-delimited line protocol from cs-roslyn-host.cs over
# the coprocess started in _cs_repl_smart. $_cs_smart_sentinel and
# $_cs_smart_accum are dynamically-scoped locals from that caller.
_cs_smart_run() {
  emulate -L zsh
  local code="$1"
  local resp_status line
  local -a out_lines

  print -p "RUN"
  print -p -r -- "$code"
  print -p -- "$_cs_smart_sentinel"

  if ! read -p resp_status; then
    print -u2 "cs: smart host exited unexpectedly"
    return 1
  fi
  out_lines=()
  while read -p line; do
    [[ "$line" == "$_cs_smart_sentinel" ]] && break
    out_lines+=("$line")
  done
  (( ${#out_lines[@]} > 0 )) && printf '%s\n' "${out_lines[@]}"
  [[ "$resp_status" == "OK" ]] && _cs_smart_accum+="$code"$'\n'
  print --
}

# ZLE widget bound to Tab only while _cs_repl_smart's keymap is active.
# Queries the host for real semantic completions against the accumulated
# session code + whatever's typed so far. Single match: inserted at the
# cursor. Multiple: listed via 'zle -M' (no prefix-replacement yet — see
# README's Smart interactive mode section for this known limitation).
_cs_smart_complete() {
  emulate -L zsh
  local full_text pos resp_status line
  local -a candidates

  full_text="${_cs_smart_accum}${BUFFER}"
  pos=$(( ${#_cs_smart_accum} + CURSOR ))

  print -p "COMPLETE"
  print -p "$pos"
  print -p -r -- "$full_text"
  print -p -- "$_cs_smart_sentinel"

  if ! read -p resp_status; then
    zle -M "cs: smart host exited unexpectedly"
    return
  fi
  candidates=()
  while read -p line; do
    [[ "$line" == "$_cs_smart_sentinel" ]] && break
    candidates+=("$line")
  done

  if (( ${#candidates[@]} == 1 )); then
    LBUFFER+="${candidates[1]}"
  elif (( ${#candidates[@]} > 1 )); then
    zle -M "${(j:, :)candidates}"
  else
    zle -M "(no completions)"
  fi
}

# Bound to Ctrl-D only while _cs_repl_smart's keymap is active. zsh's
# plain `read` treats Ctrl-D-on-empty-line as EOF for free, but `vared`
# (needed so Tab-completion can work while editing) has no such notion —
# its default Ctrl-D binding just tries to delete-char-or-list. So this
# widget fakes it: on an empty buffer, flag EOF and end editing via
# accept-line (vared has no error-exit signal to check instead); with
# text present, Ctrl-D behaves normally (delete the char under cursor).
_cs_smart_eof_widget() {
  if [[ -z "$BUFFER" ]]; then
    _cs_smart_eof=1
    zle accept-line
  else
    zle delete-char-or-list
  fi
}

# True if $1 has balanced (), {}, []. Doesn't understand string/char
# literals, so a literal containing an unmatched bracket (e.g. "(") will
# misjudge — an accepted known limitation for this heuristic, not a
# real parser. Used by _cs_repl_smart to decide "run this line now" vs
# "keep prompting for continuation" without needing dotnet-script's
# actual incremental parser.
_cs_smart_is_balanced() {
  emulate -L zsh
  local text="$1" ch depth=0 i
  for (( i = 1; i <= ${#text}; i++ )); do
    ch="${text[i]}"
    case "$ch" in
      '('|'{'|'[') (( depth++ )) ;;
      ')'|'}'|']') (( depth-- )) ;;
    esac
  done
  (( depth <= 0 ))
}

# Smart interactive loop (`cs --smart`): unlike _cs_repl below, this keeps a
# single long-lived `dotnet run cs-roslyn-host.cs` process alive for the
# whole session via zsh's coproc, so variables persist across entries and
# Tab queries it for real semantic completion. Opt-in only — the default
# REPL stays the stateless, dependency-light scratchpad it's always been.
#
# Uses `vared` rather than `read -e` to read lines: on this zsh, `read -e`
# silently fails to populate its target variable (verified interactively —
# not a documented restriction, but reproducible), while `vared` reliably
# does and is the standard way to get a Tab-bindable ZLE buffer into a
# shell variable.
_cs_repl_smart() {
  emulate -L zsh
  local host_file="${SHRP_HOME:-$HOME/.shrp}/cs-roslyn-host.cs"
  if [[ ! -f "$host_file" ]]; then
    print -u2 "cs: smart mode needs $host_file — reinstall shrp to fetch it."
    return 1
  fi

  local _cs_smart_sentinel="CSSMARTEOM"
  local _cs_smart_accum=""
  local _cs_smart_eof=0
  local line
  local -a lines

  print -- "shrp smart interactive — variables persist, Tab completes. Ctrl-D or 'exit' quits."
  print -- "(first run restores Roslyn NuGet packages — can take a minute)"

  coproc dotnet run "$host_file"

  zle -N _cs_smart_complete
  zle -N _cs_smart_eof_widget
  bindkey -N _cs_smart_saved_main main
  # Based on the plain built-in 'emacs' keymap rather than the live 'main'
  # one, so --smart behaves the same regardless of the user's own zsh
  # plugins (e.g. zsh-autosuggestions' ghost-text bindings would otherwise
  # get copied in along with everything else 'main' has accumulated).
  bindkey -N _cs_smart_keymap emacs
  bindkey -M _cs_smart_keymap '^I' _cs_smart_complete
  bindkey -M _cs_smart_keymap '^D' _cs_smart_eof_widget
  bindkey -A _cs_smart_keymap main

  {
    while true; do
      lines=()
      while true; do
        _cs_smart_eof=0
        line=""
        if (( ${#lines[@]} == 0 )); then
          vared -p "smart> " line
        else
          vared -p "... " line
        fi

        if (( _cs_smart_eof )); then
          print
          return 0
        fi

        if [[ -z "$line" ]]; then
          break
        fi
        if (( ${#lines[@]} == 0 )) && [[ "$line" == "exit" || "$line" == "quit" ]]; then
          return 0
        fi
        lines+=("$line")

        # Run as soon as brackets balance — e.g. a plain statement runs the
        # moment you hit Enter, but 'if (x) {' keeps prompting for '... '
        # until the matching '}' closes it. A blank line (above) still
        # forces a run regardless, as an escape hatch.
        _cs_smart_is_balanced "${(F)lines}" && break
      done

      (( ${#lines[@]} == 0 )) && continue

      _cs_smart_run "${(F)lines}"
    done
  } always {
    print -p "EXIT" 2>/dev/null
    wait 2>/dev/null
    bindkey -A _cs_smart_saved_main main
    bindkey -D _cs_smart_keymap 2>/dev/null
    bindkey -D _cs_smart_saved_main 2>/dev/null
  }
}

# Interactive loop: each snippet is its own `dotnet run`, so variables
# don't persist between entries — it's a fast scratchpad, not a stateful
# REPL. Blank line runs what's been typed so far; Ctrl-D or a lone
# 'exit'/'quit' leaves the loop.
_cs_repl() {
  emulate -L zsh
  local line file
  local -a lines

  print -- "shrp interactive — blank line runs, Ctrl-D or 'exit' quits."

  while true; do
    lines=()
    while true; do
      if (( ${#lines[@]} == 0 )); then
        if ! IFS= read -r "line?cs> "; then
          print
          return 0
        fi
      else
        if ! IFS= read -r "line?... "; then
          break
        fi
      fi

      if [[ -z "$line" ]]; then
        break
      fi
      if (( ${#lines[@]} == 0 )) && [[ "$line" == "exit" || "$line" == "quit" ]]; then
        return 0
      fi
      lines+=("$line")
    done

    (( ${#lines[@]} == 0 )) && continue

    if (( ${#lines[@]} == 1 )); then
      lines[1]="$(_cs_add_semicolon_if_missing "${lines[1]}")"
    fi

    file="$(mktemp "${TMPDIR:-/tmp}/cs.XXXXXX.cs")" || {
      print -u2 "cs: failed to create temp file"
      continue
    }
    printf '%s\n' "${lines[@]}" > "$file"
    dotnet run "$file"
    print --
  done
}

cs() {
  emulate -L zsh
  local code file exit_code non_interactive=0

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
cs - run C# instantly with dotnet's file-based apps (.NET 10+)

Usage:
  cs                              Interactive REPL (blank line runs, Ctrl-D/exit quits)
  cs 'Console.WriteLine("hi");'   Inline snippet
  echo 'code' | cs                 Piped stdin
  cs <<'EOF' ... EOF               Heredoc for multiline code
  cs script.cs                     Run an existing .cs file
  cs -p                            Non-interactive: print usage instead of the REPL
  cs --smart                       Smart REPL: persistent variables + Tab completion
  cs -h, --help                    Show this help

Requires: dotnet SDK 10 or later (for file-based app support).
--smart additionally needs cs-roslyn-host.cs installed alongside cs.zsh
(ships with the normal installer) and pulls Roslyn NuGet packages on first run.
USAGE
    return 0
  fi

  if ! command -v dotnet >/dev/null 2>&1; then
    print -u2 "cs: dotnet SDK not found in PATH. Install .NET 10+ from https://dotnet.microsoft.com/download"
    return 127
  fi

  if [[ "$1" == "--smart" ]]; then
    _cs_repl_smart
    return $?
  fi

  if [[ "$1" == "-p" ]]; then
    non_interactive=1
    shift
  fi

  if [[ $# -eq 1 && -f "$1" && "$1" == *.cs ]]; then
    file="$1"
  else
    if [[ $# -gt 0 ]]; then
      code="$*"
    elif [[ ! -t 0 ]]; then
      code="$(cat)"
    elif [[ $non_interactive -eq 0 ]]; then
      _cs_repl
      return $?
    else
      print -u2 "cs: no code supplied. Run 'cs --help' for usage."
      return 64
    fi

    code="$(_cs_add_semicolon_if_missing "$code")"

    file="$(mktemp "${TMPDIR:-/tmp}/cs.XXXXXX.cs")" || {
      print -u2 "cs: failed to create temp file"
      return 1
    }
    print -r -- "$code" > "$file"
  fi

  dotnet run "$file"
  exit_code=$?

  return $exit_code
}
