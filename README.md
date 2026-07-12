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

# Inline snippet
cs 'Console.WriteLine(DateTime.Now);'

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
scratchpad, not a stateful session.

If you want the old "print usage and exit" behavior instead of the REPL
(e.g. for scripting against `cs` from a non-interactive-but-still-a-tty
context), pass `-p`.

The exit code of your program is passed through when running a single
snippet, so `cs '...' && next-thing` works as expected.

## How it works

`cs` writes your snippet to a uniquely-named file (`$TMPDIR/cs.XXXXXX.cs`, via `mktemp`) and runs `dotnet run <file>`, streaming the output straight through. Passing an existing `.cs` file skips the temp file entirely and runs your file in place.

The first run of a given snippet includes compilation; dotnet caches build artifacts elsewhere, so repeated runs of the same file are fast.

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
