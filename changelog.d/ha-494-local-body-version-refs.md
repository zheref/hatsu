## HA#494 — Refresh local PR body versions after catch-up

Version-reference inspection accepts `--body-file <local-draft>`; `--write` updates every exact old-version token on unambiguous draft lines and prints ambiguous lines unchanged. The helper never edits a remote PR or generated mirror. Ao now names the draft rewrite and how to refresh catch-up-invalidated body facts.
