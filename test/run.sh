#!/bin/sh
# Runs the ShellSpec test suite (spec/), fetching ShellSpec itself into
# test/.shellspec-bin if it isn't already on PATH. Pinned to a released
# tag via `git clone`, not curl-piped-into-sh, so nothing unreviewed
# runs as part of testing.
set -eu

SHELLSPEC_VERSION="0.28.1"
# shellcheck disable=SC1007
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
vendor_dir="$script_dir/.shellspec-bin"

if command -v shellspec >/dev/null 2>&1; then
  exec shellspec "$@"
fi

if [ ! -x "$vendor_dir/bin/shellspec" ]; then
  echo "ShellSpec not found on PATH; fetching pinned $SHELLSPEC_VERSION into $vendor_dir" >&2
  rm -rf "$vendor_dir"
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$SHELLSPEC_VERSION" \
    https://github.com/shellspec/shellspec.git "$vendor_dir"
fi

exec "$vendor_dir/bin/shellspec" "$@"
