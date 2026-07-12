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

# The REPL and -p's usage-on-bare-tty behavior only differ when stdin is
# an actual terminal, which this script's own stdin may not be. Drive
# a real pty via Python (present on GitHub Actions ubuntu-latest and
# most dev machines) to exercise that path for real.
if command -v python3 >/dev/null 2>&1; then
  repl_out="$(python3 "$script_dir/repl_harness.py" "$script_dir/..")"
  if [[ "$repl_out" == *"after blank"* ]]; then
    print -- "ok - interactive REPL runs a snippet after a blank line"
    (( pass++ ))
  else
    print -u2 -- "not ok - interactive REPL runs a snippet after a blank line"
    print -u2 -- "$repl_out"
    (( fail++ ))
  fi
else
  print -- "skip - python3 not found, skipping REPL pty test"
fi

print -- "-- $pass passed, $fail failed --"
[[ $fail -eq 0 ]]
