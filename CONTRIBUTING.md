# Contributing

Thanks for considering a contribution to `shrp`. It's a small project on
purpose — keep changes focused.

## Setup

You need .NET SDK 10+ and zsh. Clone the repo and source `cs.zsh` directly
to iterate without reinstalling:

```sh
git clone https://github.com/RuslanPr0g/shrp.git
cd shrp
source cs.zsh
cs 'Console.WriteLine("testing");'
```

## Before opening a PR

Run the test suite ([ShellSpec](https://shellspec.info/); see `spec/`):

```sh
./run-tests.sh
```

This fetches ShellSpec itself if it's not already on your `PATH` — see the
README's Testing section for details. `python3` is required for the
pty-based tests covering the interactive REPL, `-p`, and `--smart` (the
`--smart` specs restore real NuGet packages the first time, so expect them
to be slower).

If you have [ShellCheck](https://www.shellcheck.net/) installed, run it
against `install.sh` and `run-tests.sh` (it doesn't support zsh, so it
can't check `cs.zsh`, and `spec/*.sh` are ShellSpec DSL, not standalone
scripts):

```sh
shellcheck install.sh run-tests.sh
```

## Commit messages

This repo uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <short summary>

<optional body explaining why, wrapped at ~72 cols>
```

Common types: `feat`, `fix`, `docs`, `refactor`, `test`, `ci`, `chore`.

Examples:

```
fix: reject symlinked temp paths before deletion
docs: add install one-liner to README
feat: support running an existing .cs file in place
```

## Pull requests

- Keep PRs scoped to one change.
- Add an entry to `CHANGELOG.md` for every change, no exceptions.
- Check whether `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, or `SECURITY.md`
  need updating too — don't assume only one doc is affected.
- Explain *why* in the PR description, not just what changed.

## Reporting bugs / requesting features

Open a GitHub issue. Include your `dotnet --version`, OS/shell, and — for
bugs — the exact `cs '...'` invocation that reproduces the problem.
