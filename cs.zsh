# shrp - run C# instantly with dotnet's file-based apps (.NET 10+)
#
# Usage:
#   cs                              # interactive REPL (blank line runs, Ctrl-D/exit quits)
#   cs 'Console.WriteLine("hi");'   # inline snippet
#   echo 'code' | cs                # piped stdin
#   cs <<'EOF' ... EOF              # heredoc for multiline code
#   cs script.cs                    # run an existing .cs file
#   cs -p                           # non-interactive: print usage instead of the REPL
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
  cs -h, --help                    Show this help

Requires: dotnet SDK 10 or later (for file-based app support).
USAGE
    return 0
  fi

  if ! command -v dotnet >/dev/null 2>&1; then
    print -u2 "cs: dotnet SDK not found in PATH. Install .NET 10+ from https://dotnet.microsoft.com/download"
    return 127
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
