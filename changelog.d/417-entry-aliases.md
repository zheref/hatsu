### Fixed

- PR section validation now executes through installed Hatsu directory and file symlinks, compares real filesystem paths, and reports a failed CLI entry resolution instead of silently succeeding. Library imports stay inert. Closes #417.

- The Node toolchain now checks for `import.meta.main` as well as the `>=22.18` floor. Node 23 and 24.0–24.1 lack this capability and are refused; supported Node 22.18+ and 24.2+ retain inert library imports. The section checker also refuses unsupported hosts directly, including when its CLI entry path cannot be resolved.

- Clause-id and Hanten findings guards also compare real filesystem paths for installed aliases. CI now selects the PR sections fixture once and refuses missing fixtures or failing verdicts.
