#!/bin/sh
# shrp installer — copies cs.zsh to ~/.shrp and wires it into ~/.zshrc.
# Safe to re-run; it won't add duplicate lines.
set -eu

REPO_RAW="https://raw.githubusercontent.com/RuslanPr0g/shrp/master/cs.zsh"
INSTALL_DIR="${SHRP_HOME:-$HOME/.shrp}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
SOURCE_LINE="source \"$INSTALL_DIR/cs.zsh\""

mkdir -p "$INSTALL_DIR"

# Prefer a local copy when running from a cloned repo; otherwise download.
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
