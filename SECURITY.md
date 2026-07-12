# Security Policy

`shrp` is a small personal-use utility, not a security-critical service,
but it does execute arbitrary code by design (that's the point of `cs`) and
has previously had scrutiny around temp-file handling.

## Reporting a vulnerability

If you find a security issue — e.g. a way `cs` could be tricked into
reading/writing a file outside the path you gave it, or a flaw in
`install.sh` — please open a GitHub issue, or use GitHub's private
["Report a vulnerability"](https://github.com/RuslanPr0g/shrp/security/advisories/new)
flow if you'd rather not disclose it publicly first.

There's no bounty program; this is a hobby project. Responsible disclosure
is appreciated and credited.
