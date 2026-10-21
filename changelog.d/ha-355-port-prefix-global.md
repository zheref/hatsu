### Changed

- **#355 Port rulings are `PT-{n}` from one global counter** ([#355](https://github.com/zheref/hatsu/issues/355)). The maintainer ruled on 2026-10-21, recorded in `docs/ROSTER.md` § *Rulings of 2026-10-21 — the port rule prefix (HA#355)*: the ports rule prefix is `PT`, and one counter runs across every pair file of the rulings directory. The answer re-confirms the open HA-PR-#391's HR-9. `templates/ports/pair.md` carries `prefix: PT · numbering: global`. Citations keep the ruled form `<from>--<to> PT-<n> (branch <ref>, unmerged)`.
- `scripts/port_rule_reserve.sh` reads every `<rulingsDir>/*.md` (the `--pair-file`'s own directory) at the tip, at the run's HEAD and working tree, on every sibling `ports-*` branch, and in every open same-repository PR touching one. The next id is one past the highest anywhere. `--check` refuses one id in two pair files, including a tip row in a different file.
- **Exit 2:** a `--pair-file` with an empty, `.` or `..` segment; a `--prefix` other than `PT`; a malformed `--target`.
- **Exit 3:** a pair file declaring another prefix or numbering; a pair file named out of shape, its path printed. A row's first cell is read with any padding.
- **Exit 1, nothing reserved:** a failed git listing, blob or working-tree read.
- **Never read, or not others:** a fork PR is never read and is listed by number only. The run's own push and own PR are not "others" to `--check`. A local head that is a PR checkout or tracks another remote is skipped, named.
- Every earlier refusal keeps its exit code. The `port-rule-guard` fixture proves each case (60 checks).
- `hatsu:bankai-rule` §§ 2–3 state the rulings-path grammar and the prefix and header refusals. § 3 drops the G5 stop that held the global case. `hatsu:kamui` and `hatsu:bankai-handbooks` lose stale "not landed" and "ruled on its adoption PR" wording.
- The open-PR reads stay residue until zheref/nen#456.
- Plugin bumped to 0.130.0.
