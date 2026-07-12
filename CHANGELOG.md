# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project doesn't cut version tags (it's installed via `install.sh`
tracking `master`), so entries are grouped as `Unreleased` until noted
otherwise.

## Unreleased

### Added

- Interactive REPL: bare `cs` in a terminal now drops into a loop —
  type lines, blank line runs them, `exit`/`quit`/Ctrl-D leaves. Each
  entry is a fresh `dotnet run`, so there's no variable persistence
  across entries.
- `-p` flag: forces the old "print usage and exit" behavior instead of
  entering the REPL.
- `CLAUDE.md`, `CONTRIBUTING.md`, `SECURITY.md`, this changelog, issue/PR
  templates, and CI (ShellCheck + smoke tests) for contributor workflow.
- `CLAUDE.md` rule: every change must get a changelog entry, and all docs
  (listed there) must be checked for needed updates before a change is
  considered done.
- Auto-semicolon: a single-line snippet (inline, piped, or a one-line
  REPL entry) that doesn't already end in `;`, `{`, or `}` now gets a
  `;` appended automatically, so `cs 'Console.WriteLine(1+1)'` works
  without remembering the trailing semicolon. Multi-line input is left
  untouched.

### Changed

- Temp-file handling simplified to write-and-leave: `cs` writes each
  snippet to a uniquely-named `cs.XXXXXX.cs` file in `$TMPDIR`/`/tmp` and
  never deletes it. Earlier cleanup logic (temp directories, deletion
  guards against symlink swaps and `..` traversal) was removed entirely —
  see the Safety section in `README.md` for why.
- Replaced the hand-rolled `test/smoke.sh` pass/fail script with a real
  [ShellSpec](https://shellspec.info/) suite (`spec/cs_spec.sh`,
  BDD-style `Describe`/`It`). `run-tests.sh` (repo root) is now the single
  entry point for running tests locally or in CI — it uses `shellspec`
  from `PATH` if present, otherwise fetches a pinned tag via `git clone`
  into `.shellspec-bin` (deliberately not a piped installer script). The
  pty test driver moved to `spec/support/repl_harness.py` and was
  generalized to take the invocation (`cs` or `cs -p`) as an argument, so
  it now also covers `-p`'s tty-forced usage message, which the old smoke
  test couldn't test at all. Everything test-related now lives under
  `spec/` plus `run-tests.sh` — no separate `test/` directory.

## 0.1.0 — initial release

### Added

- `cs` zsh function: run a C# snippet inline, via piped stdin, via
  heredoc, or by pointing at an existing `.cs` file — powered by .NET 10's
  file-based apps (`dotnet run some.cs`, no `.csproj`).
- `install.sh` one-liner installer that wires `cs.zsh` into `~/.zshrc`.
- `--help` output and clear errors when `dotnet` is missing or no code is
  supplied.
