# shrp - run C# instantly with dotnet's file-based apps (.NET 10+)
#
# Usage:
#   cs 'Console.WriteLine("hi");'   # inline snippet
#   echo 'code' | cs                # piped stdin
#   cs <<'EOF' ... EOF              # heredoc for multiline code
#   cs script.cs                    # run an existing .cs file
#   cs -h | --help                  # show help
#
# Snippets are written to a uniquely-named file in $TMPDIR (or /tmp) and
# left there — no cleanup, no deletion logic. The files are tiny and
# /tmp is typically tmpfs or swept on reboot, so deleting them isn't
# worth any risk of touching the wrong path.
cs() {
  emulate -L zsh
  local code file exit_code

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
cs - run C# instantly with dotnet's file-based apps (.NET 10+)

Usage:
  cs 'Console.WriteLine("hi");'   Inline snippet
  echo 'code' | cs                 Piped stdin
  cs <<'EOF' ... EOF               Heredoc for multiline code
  cs script.cs                     Run an existing .cs file
  cs -h, --help                    Show this help

Requires: dotnet SDK 10 or later (for file-based app support).
USAGE
    return 0
  fi

  if ! command -v dotnet >/dev/null 2>&1; then
    print -u2 "cs: dotnet SDK not found in PATH. Install .NET 10+ from https://dotnet.microsoft.com/download"
    return 127
  fi

  if [[ $# -eq 1 && -f "$1" && "$1" == *.cs ]]; then
    file="$1"
  else
    if [[ $# -gt 0 ]]; then
      code="$*"
    elif [[ ! -t 0 ]]; then
      code="$(cat)"
    else
      print -u2 "cs: no code supplied. Run 'cs --help' for usage."
      return 64
    fi

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
