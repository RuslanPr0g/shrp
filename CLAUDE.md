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

## Auto-semicolon

`_cs_add_semicolon_if_missing` appends `;` to a single-line snippet that
doesn't already end in `;`, `{`, or `}` — used by `cs` (inline/piped) and
`_cs_repl` (single-line entries only). Multi-line input is detected by
the presence of a newline and left untouched on purpose: inserting a
semicolon in the wrong place in a multi-statement snippet would silently
change behavior instead of giving a compiler error. Don't extend this to
guess across multiple lines.

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

Tests are [ShellSpec](https://shellspec.info/) specs in `spec/cs_spec.sh`
(`Describe`/`It`, BDD-style). Before committing a change to `cs.zsh` or
`install.sh`, run:

```sh
./run-tests.sh
```

`run-tests.sh` (repo root, alongside `install.sh`) uses `shellspec` from
`PATH` if present, otherwise fetches a pinned tag into `.shellspec-bin`
via `git clone` — **never** switch this to a curl-piped installer script;
that's an unreviewed-code-execution pattern and will get blocked/rejected.
If you need to bump the pinned version, edit `SHELLSPEC_VERSION` in
`run-tests.sh`, and re-run the suite locally against it before pushing.

`Include ./cs.zsh` sources the function directly into each spec run, so
most specs use `When call cs ...` (in-process, fast). The REPL and `-p`'s
tty-forced behavior can't be exercised that way — ShellSpec's `Data` block
still looks like a pipe to `-t 0`, not a terminal — so those specs use
`spec/support/repl_harness.py`, a small pty driver invoked via `When run`.
Extend `spec/cs_spec.sh` (and `repl_harness.py` if a new pty scenario is
needed) when you add behavior; don't reach for a different framework or
add a second one for a project this size.

Everything test-related lives under `spec/` (ShellSpec's own convention,
including `spec/support/` for helper scripts) plus the single
`run-tests.sh` entry point at the repo root next to `install.sh` — there
is no separate `test/` directory; don't recreate one.

## Files

- `cs.zsh` — the `cs` function and `_cs_repl` (interactive mode)
- `install.sh` — installer (downloads or copies `cs.zsh`, wires `.zshrc`)
- `run-tests.sh` — fetches/runs ShellSpec; what CI and contributors call
- `.shellspec` — ShellSpec config (`--shell zsh`, etc.)
- `spec/cs_spec.sh` — the test suite
- `spec/spec_helper.sh` — ShellSpec's required helper file (currently empty)
- `spec/support/repl_harness.py` — pty driver used by specs to test the
  REPL and `-p`
- `.github/workflows/ci.yml` — ShellCheck (`install.sh`, `run-tests.sh`;
  ShellCheck doesn't support zsh, and `spec/*.sh` are ShellSpec DSL, not
  standalone scripts) + `run-tests.sh` on a runner with dotnet 10
