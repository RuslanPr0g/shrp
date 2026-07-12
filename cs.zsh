# shrp - run C# instantly with dotnet's file-based apps (.NET 10+)
#
# Usage:
#   cs 'Console.WriteLine("hi");'   # inline snippet
#   echo 'code' | cs                # piped stdin
#   cs <<'EOF' ... EOF              # heredoc for multiline code
#   cs script.cs                    # run an existing .cs file
#   cs -h | --help                  # show help
# Deletes $1 only if it looks exactly like a dir this script created:
# non-empty, not a symlink, and rooted under our own cs.XXXXXX temp prefix.
# Guards against rm -rf firing on "", "/", $HOME, or a swapped-out symlink.
_cs_safe_rm_tmpdir() {
  emulate -L zsh
  local d="$1" base="${2:-${TMPDIR:-/tmp}}"
  base="${base%/}"
  [[ -n "$d" && -n "$base" ]] || return 0
  [[ "$d" == "$base"/cs.??????* ]] || return 0
  [[ -d "$d" && ! -L "$d" ]] || return 0
  rm -rf -- "$d"
}

cs() {
  emulate -L zsh
  local tmpdir code file cleanup=1 exit_code tmpbase

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
    cleanup=0
  elif [[ $# -gt 0 ]]; then
    code="$*"
  elif [[ ! -t 0 ]]; then
    code="$(cat)"
  else
    print -u2 "cs: no code supplied. Run 'cs --help' for usage."
    return 64
  fi

  if [[ $cleanup -eq 1 ]]; then
    tmpbase="${TMPDIR:-/tmp}"
    tmpdir="$(mktemp -d "${tmpbase%/}/cs.XXXXXX")" || {
      print -u2 "cs: failed to create temp directory"
      return 1
    }
    # Belt-and-braces: confirm mktemp actually gave us what we asked for
    # before wiring it into a trap that will rm -rf it.
    if [[ "$tmpdir" != "${tmpbase%/}"/cs.??????* || ! -d "$tmpdir" || -L "$tmpdir" ]]; then
      print -u2 "cs: unexpected temp directory from mktemp, refusing to continue"
      return 1
    fi
    file="$tmpdir/main.cs"
    print -r -- "$code" > "$file"
    trap '_cs_safe_rm_tmpdir "$tmpdir" "$tmpbase"' EXIT INT TERM
  fi

  dotnet run "$file"
  exit_code=$?

  return $exit_code
}
