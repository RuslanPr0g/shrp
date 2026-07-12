# shrp

[![CI](https://github.com/RuslanPr0g/shrp/actions/workflows/ci.yml/badge.svg)](https://github.com/RuslanPr0g/shrp/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Run C# instantly from your terminal — no `.csproj`, no `dotnet new`, no ceremony.

```sh
$ cs 'Console.WriteLine("hello");'
hello
```

Built on [.NET 10's file-based apps](https://learn.microsoft.com/dotnet/core/tutorials/file-based-apps): `dotnet run some.cs` compiles and executes a single C# file directly, top-level-statements style. `shrp` wraps that in a tiny zsh function so a snippet is one keystroke-burst away.

## Requirements

- **.NET SDK 10+** — check with `dotnet --version`, install from [dotnet.microsoft.com](https://dotnet.microsoft.com/download)
- **zsh** (the default shell on macOS and many Linux setups)

## Install

**One-liner** (downloads `cs.zsh` to `~/.shrp` and adds a `source` line to your `~/.zshrc`):

```sh
curl -fsSL https://raw.githubusercontent.com/RuslanPr0g/shrp/master/install.sh | sh
```

**Or from a clone**, if you prefer to read what you run first (good instinct):

```sh
git clone https://github.com/RuslanPr0g/shrp.git
cd shrp && ./install.sh
```

**Or fully manual** — it's a single file:

```sh
curl -fsSL https://raw.githubusercontent.com/RuslanPr0g/shrp/master/cs.zsh -o ~/.shrp/cs.zsh --create-dirs
echo 'source ~/.shrp/cs.zsh' >> ~/.zshrc
```

Then open a new terminal (or `source ~/.zshrc`) and you're set. The installer is idempotent — re-running it updates `cs.zsh` in place without duplicating the `.zshrc` line.

## Usage

```sh
# Interactive REPL — bare `cs` in a terminal
cs

# Inline snippet (trailing semicolon optional on a single line)
cs 'Console.WriteLine(DateTime.Now)'

# Multiline heredoc
cs <<'EOF'
var primes = Enumerable.Range(2, 50).Where(n =>
    Enumerable.Range(2, (int)Math.Sqrt(n) - 1).All(d => n % d != 0));
Console.WriteLine(string.Join(", ", primes));
EOF

# Piped stdin
echo 'Console.WriteLine(Environment.OSVersion);' | cs

# Run an existing file in place
cs script.cs

# Non-interactive: print usage instead of entering the REPL
cs -p

# Smart REPL: persistent variables + Tab completion
cs --smart

# Help
cs --help
```

### Interactive mode

Run `cs` with no arguments in a terminal and you get a small REPL:

```
$ cs
shrp interactive — blank line runs, Ctrl-D or 'exit' quits.
cs> Console.WriteLine("hi");
...
hi

cs>
```

Type one or more lines, then hit Enter on a blank line to run what you've
typed. `exit`, `quit`, or Ctrl-D leaves the loop. Each entry is its own
`dotnet run`, so variables don't carry over between snippets — it's a fast
scratchpad, not a stateful session. A single-line entry doesn't need a
trailing semicolon (`cs> Console.WriteLine(6*7)` works as-is).

If you want the old "print usage and exit" behavior instead of the REPL
(e.g. for scripting against `cs` from a non-interactive-but-still-a-tty
context), pass `-p`.

The exit code of your program is passed through when running a single
snippet, so `cs '...' && next-thing` works as expected.

### Smart interactive mode

`cs --smart` is a second, opt-in REPL for when the scratchpad above isn't
enough — variables persist across entries, and Tab gives real semantic
completions:

```
$ cs --smart
shrp smart interactive — variables persist, Tab completes. Ctrl-D or 'exit' quits.
(first run restores Roslyn NuGet packages — can take a minute)
smart> int x = 5;
smart> x + 1
=> 6
smart> Console.<Tab>
WriteLine, Write, ReadLine, ...
```

How it differs from the default REPL:

- **Variables persist.** Unlike `cs`'s REPL (a fresh `dotnet run` per entry),
  `--smart` keeps one long-lived process alive for the session, so state
  from earlier entries is still there.
- **Runs on Enter, not on a blank line.** The default REPL waits for a
  blank line before running what you typed (it has to, since it batches
  possibly-multi-statement snippets into one `dotnet run`). `--smart`
  runs each entry the moment its brackets balance — a plain statement
  runs immediately, `if (x) {` keeps prompting with `... ` until the
  matching `}` closes it. A blank line still forces a run of whatever's
  accumulated, as an escape hatch.
- **Consistent editing regardless of your zsh plugins.** Tab/Ctrl-D are
  bound in a keymap based on the plain built-in `emacs` keymap, not your
  shell's live one — so e.g. `zsh-autosuggestions`-style ghost-text
  suggestions from your command history won't show up while you're
  typing C#.
- **Tab completes on real semantic info** (via Roslyn's completion API),
  not a hardcoded keyword list — it knows the members of whatever type
  you're dotting into, including your own declared variables.
- **No auto-semicolon.** The default REPL appends a missing `;` to a
  single-line entry; `--smart` doesn't, because unlike a full file-based
  app, `x + 1` here is a legal value-yielding expression on its own —
  appending `;` would make it an illegal statement instead of something
  that prints `=> 6`.
- **Extra dependency, opt-in only.** First run restores several
  `Microsoft.CodeAnalysis.*` NuGet packages (can take up to a minute);
  after that it's cached like any other `dotnet run`. The plain `cs` REPL
  is untouched and still has zero extra dependencies.
- **Known limitation:** Tab completion inserts the full suggestion at the
  cursor; it doesn't yet replace an already-partially-typed prefix (e.g.
  `Console.Wri<Tab>` won't trim `Wri` first).

Needs `cs-roslyn-host.cs` installed alongside `cs.zsh` (the installer
fetches it automatically).

## How it works

`cs` writes your snippet to a uniquely-named file (`$TMPDIR/cs.XXXXXX.cs`, via `mktemp`) and runs `dotnet run <file>`, streaming the output straight through. Passing an existing `.cs` file skips the temp file entirely and runs your file in place. (`cs --smart` works differently — see "Smart interactive mode" above.)

If your snippet is a single line and doesn't already end in `;`, `{`, or `}`, a `;` is appended automatically. Multi-line snippets (heredoc, multi-line REPL entries, existing files) are never touched this way — guessing where a semicolon belongs across statements isn't safe, so a missing one there is still a normal compiler error.

The first run of a given snippet includes compilation; dotnet caches build artifacts elsewhere, so repeated runs of the same file are fast.

## Testing

The test suite ([ShellSpec](https://shellspec.info/) specs in `spec/`) is
run with:

```sh
./run-tests.sh
```

This uses your system's `shellspec` if it's already on `PATH`; otherwise it
fetches a pinned release into `.shellspec-bin` (via `git clone`, not a
piped installer script) and uses that. Requires .NET SDK 10+ and zsh, same
as `cs` itself; `python3` is needed too, for the pty-based tests that cover
the interactive REPL, `-p`, and `--smart` (see `spec/support/repl_harness.py`).
The `--smart` specs restore real NuGet packages the first time they run in
a given environment, so they're slower than the rest of the suite.

## Safety

`shrp` never deletes anything. Earlier versions tried to clean up their temp files, which meant shipping deletion logic (`rm`, directory ownership/symlink checks, `..`-traversal guards) for files a few hundred bytes in size that `/tmp` clears out on its own — most systems mount `/tmp` as tmpfs or sweep it on reboot. Deleting was pure risk for no real benefit, so it was removed instead of hardened further. `cs` only ever writes new files under `$TMPDIR`/`/tmp`; it never touches an existing path unless you explicitly pass it (`cs script.cs`).

## Uninstall

```sh
rm -rf ~/.shrp
```

…and remove the `source` line from your `~/.zshrc`.

## Contributing

Bug reports, feature requests, and PRs are welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md). Security issues: see
[SECURITY.md](SECURITY.md). Notable changes are tracked in
[CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
