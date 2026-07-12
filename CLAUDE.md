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

## Testing

No test framework — it's one shell function. Before committing a change to
`cs.zsh` or `install.sh`, run:

```sh
zsh test/smoke.sh
```

This exercises the inline/piped/file/help code paths. Extend it when you
add behavior; don't add a heavier test framework for a project this size.

## Files

- `cs.zsh` — the `cs` function
- `install.sh` — installer (downloads or copies `cs.zsh`, wires `.zshrc`)
- `test/smoke.sh` — manual/CI smoke tests
- `.github/workflows/ci.yml` — shellcheck (install.sh only; ShellCheck
  doesn't support zsh) + the smoke test on a runner with dotnet 10
