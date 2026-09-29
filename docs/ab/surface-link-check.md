# A/B — `scripts/surface_link_check.sh`

Evidence for the generated-surface link guard (zheref/hatsu#72), recorded from live runs.

## 2026-09-28 — first sweep, at 6e86978 (mirrors regenerated at stamp 0.50.0 with nen 0.15.1)

```text
$ bash scripts/surface_link_check.sh --summary .
--- dangling links by surface · kind · link prefix
 207 antigravity · skills (nested) · ../../../docs/
   6 cursor · skill (flat) · ../../agents/
   6 codex · skill (flat) · ../../agents/
   4 cursor · agents · ../../docs/
   4 antigravity · agents · ../../docs/
   4 cursor · agents · ../skills/mugetsu/          # and every other ../skills/<name>/ row: 59 in cursor/agents
   4 codex · AGENTS.md · ../skills/mugetsu/        # and every other ../skills/<name>/ row: 56 in codex/AGENTS.md
   …
surface-link-check: 341 of 2571 relative .md link(s) under surfaces/ dangle (file, link, resolved path above). The bodies are generated: fix the generator's depth rewrite (nen surface mirror generate) and regenerate; never hand-edit a mirror.
exit=1
```

Every row is the generator's: the authored sources under `claude/` resolve, and the same text placed one
directory shallower or deeper does not. `scripts/antigravity_mirror_sync.sh` — the Hatsu-side generator
#72 named for the antigravity half — was retired before this sweep; all three mirrors come from
`nen surface mirror generate`, so the fix is zheref/nen#270 (filed from this run with the table above).

**Why it is not a CI step yet.** `nen pr ready` row 2 (CON-32(a)) requires every reported check green.
A `surface-link-check` context red on every pull request until the generator fix lands would read every
pull request not-ready for a defect none of them made; the step beside `surface-mirror-check` is the
follow-up once zheref/hatsu regenerates clean at the fixed pin. The guard, its fixture and the
`surface-link-guard` lane ship now, so the state is measurable on every checkout.

```text
$ nen shu test --repo . --lane surface-link-guard
surface-link-fixture: ok      # clean tree exit 0 (4 relative links counted, absolute/http/mailto/fragment not judged);
                              # one dangling link exit 1 with file · link · resolved path; the #71 nested-depth regression caught;
                              # --summary classes; not-a-Hatsu-root and no-surfaces/ are exit 2
```
