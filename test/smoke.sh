#!/usr/bin/env zsh
# Manual/CI smoke tests for cs.zsh. No framework — just enough to catch
# regressions in the handful of code paths cs() has. Run with:
#   zsh test/smoke.sh
emulate -L zsh
set -u

script_dir="${0:A:h}"
source "$script_dir/../cs.zsh"

pass=0
fail=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    print -- "ok - $desc"
    (( pass++ ))
  else
    print -u2 -- "not ok - $desc"
    print -u2 -- "    expected: $expected"
    print -u2 -- "    actual:   $actual"
    (( fail++ ))
  fi
}

check_contains() {
  local desc="$1" needle="$2" actual="$3"
  if [[ "$actual" == *"$needle"* ]]; then
    print -- "ok - $desc"
    (( pass++ ))
  else
    print -u2 -- "not ok - $desc"
    print -u2 -- "    expected to contain: $needle"
    print -u2 -- "    actual:               $actual"
    (( fail++ ))
  fi
}

check "inline snippet" "2" "$(cs 'Console.WriteLine(1+1);')"

check "piped stdin" "42" "$(echo 'Console.WriteLine(6*7);' | cs)"

check "heredoc" "hi" "$(cs <<'EOF'
Console.WriteLine("hi");
EOF
)"

check "help flag" "cs - run C# instantly with dotnet's file-based apps (.NET 10+)" "$(cs --help | head -1)"

f="$(mktemp "${TMPDIR:-/tmp}/smoke.XXXXXX.cs")"
print -r -- 'Console.WriteLine("from file");' > "$f"
check "existing .cs file" "from file" "$(cs "$f")"

check "-p flag doesn't interfere with an inline snippet" "still runs" "$(cs -p 'Console.WriteLine("still runs");')"

check "inline snippet without trailing semicolon" "3" "$(cs 'Console.WriteLine(1+2)')"

check "piped single line without trailing semicolon" "9" "$(echo 'Console.WriteLine(3*3)' | cs)"

check_contains "multiline missing final semicolon is left alone (fails to build)" "; expected" "$(cs <<'EOF' 2>&1
var x = 10;
Console.WriteLine(x)
EOF
)"

# The REPL and -p's usage-on-bare-tty behavior only differ when stdin is
# an actual terminal, which this script's own stdin may not be. Drive
# a real pty via Python (present on GitHub Actions ubuntu-latest and
# most dev machines) to exercise that path for real.
check_repl() {
  local desc="$1" expected_substr="$2"
  shift 2
  local out
  if ! command -v python3 >/dev/null 2>&1; then
    print -- "skip - python3 not found, skipping: $desc"
    return
  fi
  out="$(python3 "$script_dir/repl_harness.py" "$script_dir/.." "$@")"
  if [[ "$out" == *"$expected_substr"* ]]; then
    print -- "ok - $desc"
    (( pass++ ))
  else
    print -u2 -- "not ok - $desc"
    print -u2 -- "$out"
    (( fail++ ))
  fi
}

check_repl "interactive REPL runs a snippet after a blank line" "after blank" \
  'Console.WriteLine("after blank");' '' quit

check_repl "interactive REPL adds a missing semicolon on a single-line entry" "42" \
  'Console.WriteLine(6*7)' '' quit

print -- "-- $pass passed, $fail failed --"
[[ $fail -eq 0 ]]
