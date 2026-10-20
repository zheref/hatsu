### Added

- Register `AK` (`zheref/akatsuki-ai`, the Akatsuki CI plane) in `nen/repos.json`, so `AK#<n>` resolves from a Hatsu checkout. Under the maintainer's ruling of 2026-10-19 it is the one private repository whose name may be public; its code stays private (zheref/hatsu#329).
- Add a committed named list, `scripts/private_name_named.txt`. The private-name guard reads it by default and drops exactly the `owner/name` it carries. A bare name is refused, and a same-named repository under another owner is still a hit. The fixture covers it and pins the list's entry set (173 cases).

### Changed

- `hatsu:file` § 4 joins the named list with the maintainer's ignore file into the one file nen's guard takes, until zheref/nen#441. `hatsu:file`, `backlog-synthesis`, `mugetsu` and `sharingan` now always pass that file to nen's issue writers. `hatsu:build` § 1 resolves a code against the checkout it stands in, as `classify` does. The private-name guard is BC-11 debt: it is frozen to fixes only until nen ports it (zheref/nen#441). `docs/PUBLIC-REDACTION.md` and `docs/ROSTER.md` record the exception.
