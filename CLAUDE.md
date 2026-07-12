# CLAUDE.md

Guidance for Claude Code (or any agent) working in this repo.

## What this is

`shrp` is a single zsh function (`cs`, in `cs.zsh`) that runs C# snippets via
.NET 10's file-based apps (`dotnet run some.cs`, no `.csproj`). `install.sh`
installs it. That's the whole project — resist growing it into more than
that without a concrete reason.

## Conventions

- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/).
  `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `ci:`, `chore:`. Body
  explains *why*, not what (the diff already shows what). Wrap at ~72 cols.
- **No comments explaining what code does.** Only comment on non-obvious
  *why* (see the header comment in `cs.zsh` for the tone to match).
- **Shell dialects matter**: `cs.zsh` is zsh-only (uses `emulate -L zsh`,
  `${var:A}`, `print`) — don't try to make it POSIX-portable. `install.sh`
  is deliberately plain POSIX `sh` so it works via `curl | sh` regardless of
  the user's shell.

## Safety principle (read before touching cleanup/temp-file logic)

Earlier versions of `cs.zsh` created a temp *directory* and deleted it after
each run, with increasingly paranoid guards against `rm -rf` hitting the
wrong path (symlink swaps, `..` traversal, etc.). That was all removed —
see the README's Safety section. The current design writes a uniquely-named
file straight into `$TMPDIR`/`/tmp` via `mktemp` and never deletes anything.

**Do not reintroduce deletion logic** (`rm`, `rmdir`, cleanup traps) without
a real reason, and if you do, keep in mind the standing bar: no recursive
delete, and validate any path before it's ever removed. Simpler and safer to
just not delete.

## Interactive mode

Bare `cs` in a terminal (no args, stdin is a tty) enters `_cs_repl`: a loop
that reads lines until a blank one, then runs them as one snippet.
`exit`/`quit`/Ctrl-D leave the loop. `cs -p` forces the old behavior
(print usage, exit) instead of entering the REPL — useful when `cs` is
invoked from something that has a tty but isn't an interactive human
(rare, but that's what the flag is for). Each REPL entry is a fresh
`dotnet run`, so there is deliberately no variable persistence across
entries — don't add a stateful scripting host (e.g. `dotnet-script`) to
get that without discussing it first; it's a real dependency and
architecture change, not a small addition.

## Before you finish any change

Every change must be logged in `CHANGELOG.md` (under `Unreleased`, in
the right Added/Changed/Fixed/Removed section). No exceptions — even a
one-line fix gets an entry.

Also check every doc below and update any that the change affects. Go
through the list explicitly rather than guessing which ones are
relevant:

- `README.md`
- `CLAUDE.md` (this file)
- `CONTRIBUTING.md`
- `SECURITY.md`
- `CHANGELOG.md`

## Testing

No test framework — it's one shell function. Before committing a change to
`cs.zsh` or `install.sh`, run:

```sh
zsh test/smoke.sh
```

This exercises the inline/piped/file/help/`-p` code paths, plus the
interactive REPL via `test/repl_harness.py` (drives a real pty with
Python's `pty` module, since `-t 0` can't be faked with a plain pipe — see
that file for why). Extend the smoke test when you add behavior; don't add
a heavier test framework for a project this size.

## Files

- `cs.zsh` — the `cs` function and `_cs_repl` (interactive mode)
- `install.sh` — installer (downloads or copies `cs.zsh`, wires `.zshrc`)
- `test/smoke.sh` — manual/CI smoke tests
- `test/repl_harness.py` — pty driver used by smoke.sh to test the REPL
- `.github/workflows/ci.yml` — shellcheck (install.sh only; ShellCheck
  doesn't support zsh) + the smoke test on a runner with dotnet 10
