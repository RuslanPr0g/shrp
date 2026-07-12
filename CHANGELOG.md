# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project doesn't cut version tags (it's installed via `install.sh`
tracking `master`), so entries are grouped as `Unreleased` until noted
otherwise.

## Unreleased

### Added

- `CLAUDE.md`, `CONTRIBUTING.md`, `SECURITY.md`, this changelog, issue/PR
  templates, and CI (ShellCheck + smoke tests) for contributor workflow.

### Changed

- Temp-file handling simplified to write-and-leave: `cs` writes each
  snippet to a uniquely-named `cs.XXXXXX.cs` file in `$TMPDIR`/`/tmp` and
  never deletes it. Earlier cleanup logic (temp directories, deletion
  guards against symlink swaps and `..` traversal) was removed entirely —
  see the Safety section in `README.md` for why.

## 0.1.0 — initial release

### Added

- `cs` zsh function: run a C# snippet inline, via piped stdin, via
  heredoc, or by pointing at an existing `.cs` file — powered by .NET 10's
  file-based apps (`dotnet run some.cs`, no `.csproj`).
- `install.sh` one-liner installer that wires `cs.zsh` into `~/.zshrc`.
- `--help` output and clear errors when `dotnet` is missing or no code is
  supplied.
