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
entries in this default REPL — it stays a stateless, dependency-light
scratchpad. See "Smart interactive mode" below for the opt-in mode that
does add persistence.

## Smart interactive mode

`cs --smart` (`_cs_repl_smart`) is a second, opt-in REPL, separate from
`_cs_repl` above, for persistent variables and real Tab completion. This
is the stateful-scripting-host addition earlier versions of this file
warned against without discussion — it's now built, scoped narrowly:

- **Opt-in only.** The default `cs` REPL is untouched: still stateless,
  still zero extra dependencies. `--smart` is a deliberate, separate ask.
- **Companion process**: `cs-roslyn-host.cs`, a long-lived file-based app
  wrapping `Microsoft.CodeAnalysis.CSharp.Scripting`, started once per
  `_cs_repl_smart` invocation via zsh's `coproc` and torn down (an `EXIT`
  message, then `wait`) in an `always {}` block so it's cleaned up on every
  exit path. `install.sh` ships it alongside `cs.zsh`; `cs.zsh` locates it
  via `$SHRP_HOME` (same env var `install.sh` already uses), not a
  path-resolution trick.
- **Protocol**: a small sentinel-delimited line protocol over the coproc's
  stdin/stdout (`RUN`/`COMPLETE`/`EXIT`, each request and response ending
  in a literal `CSSMARTEOM` line) — deliberately not JSON, to keep the zsh
  side simple. See `cs-roslyn-host.cs` and `_cs_smart_run`/
  `_cs_smart_complete` in `cs.zsh`. `HandleRunAsync` in the host
  temporarily redirects `Console.Out` to a `StringWriter` while running
  user code and folds the captured text into the response body — without
  this, a script's own `Console.WriteLine` would land on the same stdout
  stream as the `OK`/sentinel lines and desync the client's read loop
  (this actually happened; the visible symptom was the literal word `OK`
  printed instead of the script's real output).
- **Input uses `vared`, not `read -e`.** `read -e` was tried first and
  silently fails to populate its target variable on this zsh (reproduced
  interactively, not just in this repo) — `vared` is what actually works
  and is the standard way to get a Tab-bindable ZLE buffer into a shell
  variable. Ctrl-D has no free EOF signal under `vared` the way plain
  `read` gives it, so there's a dedicated widget (`_cs_smart_eof_widget`)
  faking it via a flag variable + `accept-line` on an empty buffer.
- **Runs on Enter once brackets balance**, not on a blank line —
  `_cs_smart_is_balanced` counts `()`/`{}`/`[]` across the accumulated
  entry (it doesn't understand string/char literals; a bracket inside a
  string quote can misjudge — accepted heuristic limitation, not a real
  parser) and the read loop breaks out to run as soon as it balances. A
  blank line still forces a run of whatever's accumulated regardless, as
  an escape hatch. This differs from `_cs_repl`, which always waits for a
  blank line — that made sense there since it batches a possibly
  multi-statement snippet into a single `dotnet run`; `--smart` doesn't
  need to batch, so waiting for a second blank Enter after every already-
  complete statement was just extra friction.
- **Tab completion** is bound only inside a temporary keymap
  (`_cs_smart_keymap`, based on the plain built-in `emacs` keymap rather
  than the live `main` one — copying `main` would also drag in whatever
  the user's own zsh plugins bound there, e.g. `zsh-autosuggestions`
  ghost-text, which showed up during testing and was confusing — then
  linked in via `bindkey -A ... main` and restored from a saved copy of
  the real `main` on exit) so it doesn't leak into the rest of the user's
  shell. It inserts the single unambiguous suggestion at the cursor, or
  lists multiple via `zle -M` — no prefix-replacement yet.
- **No auto-semicolon in `--smart`.** Unlike `_cs_repl`, a bare expression
  like `x + 1` is a legal value-yielding statement in Roslyn's scripting
  model; forcing a trailing `;` onto it turns it into an illegal C#
  statement (`CS0201`) instead of something that prints `=> 6`. Don't add
  the auto-semicolon call back into `_cs_repl_smart`.
- Still don't reintroduce `rm`/cleanup logic for the temp-file-writing
  parts of `cs`/`_cs_repl` — that principle above is unrelated to killing
  the coproc, which is a process, not a file.

## Auto-semicolon

`_cs_add_semicolon_if_missing` appends `;` to a single-line snippet that
doesn't already end in `;`, `{`, or `}` — used by `cs` (inline/piped) and
`_cs_repl` (single-line entries only, and *not* `_cs_repl_smart` — see
"Smart interactive mode" above for why). Multi-line input is detected by
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

- `cs.zsh` — the `cs` function, `_cs_repl` (default interactive mode), and
  `_cs_repl_smart`/`_cs_smart_run`/`_cs_smart_complete`/
  `_cs_smart_eof_widget` (smart interactive mode)
- `cs-roslyn-host.cs` — long-lived Roslyn scripting host backing `cs --smart`
- `install.sh` — installer (downloads or copies `cs.zsh` and
  `cs-roslyn-host.cs`, wires `.zshrc`)
- `run-tests.sh` — fetches/runs ShellSpec; what CI and contributors call
- `.shellspec` — ShellSpec config (`--shell zsh`, etc.)
- `spec/cs_spec.sh` — the test suite
- `spec/spec_helper.sh` — ShellSpec's required helper file (currently empty)
- `spec/support/repl_harness.py` — pty driver used by specs to test the
  REPL, `-p`, and `--smart` (the latter needs `REPL_HARNESS_INTERACTIVE=1`
  so zsh initializes zle/vared, and a `RAW:`-prefixed input line for
  sending un-terminated keystrokes like Tab)
- `.github/workflows/ci.yml` — ShellCheck (`install.sh`, `run-tests.sh`;
  ShellCheck doesn't support zsh, and `spec/*.sh` are ShellSpec DSL, not
  standalone scripts) + `run-tests.sh` on a runner with dotnet 10
