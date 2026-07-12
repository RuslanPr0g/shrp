# shrp

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

# Help
cs --help
```

Called with no arguments and nothing piped in, `cs` prints usage instead of hanging. The exit code of your program is passed through, so `cs '...' && next-thing` works as expected.

## How it works

`cs` writes your snippet to `main.cs` inside a fresh `mktemp` directory, runs `dotnet run <file>`, streams the output, and cleans up — including on Ctrl-C. Passing an existing `.cs` file skips the temp dir entirely and runs the file in place (and never deletes it).

The first run of a given snippet includes compilation; dotnet caches build artifacts (in its own cache, not the temp dir), so repeated runs of the same file are fast.

## Safety

Shell scripts that delete temp directories deserve suspicion, so cleanup here is deliberately paranoid:

- **No recursive delete.** Cleanup removes exactly the one `main.cs` the script wrote, then `rmdir`s the directory. If anything unexpected is inside, it's left untouched and reported.
- The cleanup helper refuses to act unless the path is a real directory (not a symlink), owned by the current user, matches the script's own `cs.XXXXXX` naming, and its **resolved** real path is still a `cs.XXXXXX` directory directly under the temp base — so empty strings, `/`, `$HOME`, `..` traversal, and symlink-swap races are all rejected.
- The `mktemp` result is validated against the same rules before it's ever wired into the cleanup trap.
- Your own `.cs` files (the `cs script.cs` form) never enter the cleanup path at all.

## Uninstall

```sh
rm -rf ~/.shrp
```

…and remove the `source` line from your `~/.zshrc`.

## License

[MIT](LICENSE)
