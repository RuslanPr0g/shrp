Describe 'cs'
  Include ./cs.zsh

  It 'runs an inline snippet'
    When call cs 'Console.WriteLine(1+1);'
    The output should eq "2"
  End

  It 'reads piped stdin'
    Data
      #|Console.WriteLine(6*7);
    End
    When call cs
    The output should eq "42"
  End

  It 'runs a multiline snippet from stdin (heredoc-equivalent)'
    Data
      #|var primes = new[] { 2, 3, 5 };
      #|Console.WriteLine(string.Join(",", primes));
    End
    When call cs
    The output should eq "2,3,5"
  End

  It 'runs an existing .cs file in place'
    f="${SHELLSPEC_TMPBASE}/existing_$$.cs"
    echo 'Console.WriteLine("from file");' > "$f"
    When call cs "$f"
    The output should eq "from file"
  End

  It 'shows help with -h'
    When call cs -h
    The line 1 of output should eq "cs - run C# instantly with dotnet's file-based apps (.NET 10+)"
  End

  It 'shows help with --help'
    When call cs --help
    The line 1 of output should eq "cs - run C# instantly with dotnet's file-based apps (.NET 10+)"
  End

  It '-p does not interfere with an inline snippet'
    When call cs -p 'Console.WriteLine("still runs");'
    The output should eq "still runs"
  End

  It 'appends a missing semicolon on a single-line inline snippet'
    When call cs 'Console.WriteLine(1+2)'
    The output should eq "3"
  End

  It 'appends a missing semicolon on a single-line piped snippet'
    Data
      #|Console.WriteLine(3*3)
    End
    When call cs
    The output should eq "9"
  End

  It 'leaves a multiline snippet missing its final semicolon alone (compiler error, not silently fixed)'
    Data
      #|var x = 10;
      #|Console.WriteLine(x)
    End
    When call cs
    The status should eq 1
    The output should include "; expected"
    The stderr should include "The build failed"
  End
End

Describe 'cs (real pty, since -t 0 cannot be faked with a pipe)'
  pty_run() {
    invocation="$1"
    shift
    python3 "$SHELLSPEC_PROJECT_ROOT/spec/support/repl_harness.py" "$SHELLSPEC_PROJECT_ROOT" "$invocation" "$@"
  }

  It 'REPL runs a snippet after a blank line'
    When run pty_run cs 'Console.WriteLine("after blank");' '' quit
    The output should include "after blank"
  End

  It 'REPL appends a missing semicolon on a single-line entry'
    When run pty_run cs 'Console.WriteLine(6*7)' '' quit
    The output should include "42"
  End

  It '-p prints usage instead of entering the REPL when called from a tty'
    When run pty_run "cs -p"
    The output should include "no code supplied"
  End
End

Describe 'cs --smart (persistent scope + completion; needs a real interactive zsh for zle/vared)'
  pty_run_smart() {
    invocation="$1"
    shift
    SHRP_HOME="$SHELLSPEC_PROJECT_ROOT" \
      REPL_HARNESS_INTERACTIVE=1 \
      REPL_HARNESS_TIMEOUT="${REPL_HARNESS_TIMEOUT:-90}" \
      REPL_HARNESS_GAP="${REPL_HARNESS_GAP:-6}" \
      python3 "$SHELLSPEC_PROJECT_ROOT/spec/support/repl_harness.py" "$SHELLSPEC_PROJECT_ROOT" "$invocation" "$@"
  }

  It 'persists a variable across two entries'
    When run pty_run_smart "cs --smart" 'int x = 5;' '' 'x + 1' '' exit
    The output should include "=> 6"
  End

  It 'Tab surfaces real member completions after "Console."'
    When run pty_run_smart "cs --smart" 'RAW:Console.' $'RAW:\t' '' exit
    The output should include "WriteLine"
  End
End
