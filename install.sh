#!/bin/sh
# shrp installer — copies cs.zsh to ~/.shrp and wires it into ~/.zshrc.
# Safe to re-run; it won't add duplicate lines.
set -eu

REPO_RAW="https://raw.githubusercontent.com/RuslanPr0g/shrp/master/cs.zsh"
HOST_REPO_RAW="https://raw.githubusercontent.com/RuslanPr0g/shrp/master/cs-roslyn-host.cs"
INSTALL_DIR="${SHRP_HOME:-$HOME/.shrp}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
SOURCE_LINE="source \"$INSTALL_DIR/cs.zsh\""

mkdir -p "$INSTALL_DIR"

# Prefer a local copy when running from a cloned repo; otherwise download.
# shellcheck disable=SC1007
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -f "$script_dir/cs.zsh" ]; then
  cp "$script_dir/cs.zsh" "$INSTALL_DIR/cs.zsh"
  echo "Copied cs.zsh from local checkout to $INSTALL_DIR/"
elif command -v curl >/dev/null 2>&1; then
  curl -fsSL "$REPO_RAW" -o "$INSTALL_DIR/cs.zsh"
  echo "Downloaded cs.zsh to $INSTALL_DIR/"
else
  echo "error: need curl (or run this from a cloned repo)" >&2
  exit 1
fi

# cs-roslyn-host.cs backs `cs --smart` (persistent variables + Tab
# completion). Same local-copy-vs-download preference as cs.zsh above.
if [ -f "$script_dir/cs-roslyn-host.cs" ]; then
  cp "$script_dir/cs-roslyn-host.cs" "$INSTALL_DIR/cs-roslyn-host.cs"
  echo "Copied cs-roslyn-host.cs from local checkout to $INSTALL_DIR/"
elif command -v curl >/dev/null 2>&1; then
  curl -fsSL "$HOST_REPO_RAW" -o "$INSTALL_DIR/cs-roslyn-host.cs"
  echo "Downloaded cs-roslyn-host.cs to $INSTALL_DIR/"
else
  echo "error: need curl (or run this from a cloned repo)" >&2
  exit 1
fi

if [ -f "$ZSHRC" ] && grep -Fq "$INSTALL_DIR/cs.zsh" "$ZSHRC"; then
  echo "Already wired into $ZSHRC"
else
  printf '\n# shrp — https://github.com/RuslanPr0g/shrp\n%s\n' "$SOURCE_LINE" >> "$ZSHRC"
  echo "Added source line to $ZSHRC"
fi

if ! command -v dotnet >/dev/null 2>&1; then
  echo "note: dotnet SDK not found — install .NET 10+ from https://dotnet.microsoft.com/download" >&2
fi

echo "Done. Open a new terminal (or 'source $ZSHRC') and try:"
echo "  cs 'Console.WriteLine(\"hello\");'"
