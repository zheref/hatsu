# A/B — `scripts/surface_link_check.sh`

Evidence for the generated-surface link guard (zheref/hatsu#72), recorded from live runs.

## 2026-09-28 — the sweep at 16d089f, after the pre-PR delta passes (mirrors at stamp 0.51.0, nen 0.15.1)

The first sweep judged `.md` targets in `.md` files only and read **341 of 2571**. Nobunaga showed five
non-`.md` relative targets dangling under the same depth defect (a script, a template, a JSON file, the
registry) and Phinks showed the Codex persona `.toml` bodies (58 relative links, none scanned); the guard now
judges every relative link in every generated file that carries markdown (`.md`, `.mdc`, `.toml`):

```text
$ bash scripts/surface_link_check.sh --summary .
--- dangling links by surface · kind · link prefix
 207 antigravity · skills (nested) · ../../../docs/
  55 cursor · agents · ../skills/<name>/            # summed over the per-skill rows the summary prints
  55 codex · AGENTS.md · ../skills/<name>/
  54 codex · agents (.toml) · ../skills/<name>/
   6 cursor · skill (flat) · ../../agents/
   6 codex · skill (flat) · ../../agents/
   4 cursor · agents · ../../docs/
   4 antigravity · agents · ../../docs/
   3 codex · agents (.toml) · ../../docs/
   3 antigravity · skills (nested) · ../../../templates/
   2 antigravity · skills (nested) · ../../../scripts/
   2 antigravity · skills (nested) · ../../../docs/surfaces/
   1 codex · agents (.toml) · ./                     # a sibling link (netero.md) resolved beside the persona
   1 codex · AGENTS.md · ./
   1 antigravity · skills (nested) · ../../../nen/
surface-link-check: 404 of 2644 relative link(s) under surfaces/ dangle (file, link, resolved path above). The bodies are generated: fix the generator's depth rewrite (nen surface mirror generate) and regenerate; never hand-edit a mirror.
exit=1
```

The classes sum to 404: the nested antigravity skills 215 (207 + 3 + 2 + 2 + 1), the cursor agents 59
(55 + 4), Codex's inlined `AGENTS.md` 56 (55 + 1), the Codex persona `.toml` bodies 58 (54 + 3 + 1), the
flat skills' `../../agents/` 12, the antigravity agents 4.

Every row is the generator's: the authored sources under `claude/` resolve, and the same text placed one
directory shallower or deeper does not. `scripts/antigravity_mirror_sync.sh` — the Hatsu-side generator
#72 named for the antigravity half — was retired before this sweep; all three mirrors come from
`nen surface mirror generate`, so the fix is zheref/nen#270 (filed from this run; its table corrected to
the one above after the delta passes).

**Why it is not a CI step yet.** `nen pr ready` row 2 (CON-32(a)) requires every reported check green.
A `surface-link-check` context red on every pull request until the generator fix lands would read every
pull request not-ready for a defect none of them made; the step beside `surface-mirror-check` is the
follow-up once zheref/hatsu regenerates clean at the fixed pin. Until then a new Hatsu-authored dangling
link is indistinguishable from the generator's — an accepted, stated cost. The guard, its fixture and the
`surface-link-guard` lane ship now, so the state is measurable on every checkout: **the lane runs the
fixture (hermetic; green says the guard works, never that the mirrors are clean); the live verdict is the
script itself, by hand.**

```text
$ nen shu test --repo . --lane surface-link-guard
surface-link-fixture: ok      # a clean tree is exit 0 (6 relative links counted across .md and a .toml body; absolute/http/mailto/fragment not judged);
                              # an extra positional is refused (exit 2); one dangling link is exit 1 with file · link · resolved path;
                              # the #71 nested-depth regression is caught; a dangling non-.md target (a template) is reported and a resolving
                              # one (a script) is not; a dangling link inside a persona .toml is reported; an unreadable file and an empty
                              # surfaces/ are exit 2; --summary prints the classes; not-a-Hatsu-root and no-surfaces/ are exit 2
```

**Residue.** Angle-bracket (`](<x>)`) and titled (`](x "t")`) link forms are not matched — none exists in
the mirrors; a directory named `*.md` would satisfy `-e`; on GNU grep a binary match goes to stderr, which
the guard does not silence, so a NUL-bearing file reads as a garbage row and fails closed (BSD grep prints
it on stdout, same outcome). Uvogin's numbers were not taken: the sweep runs in about half a second on
this host (a diagnostic, not a QA-15 reading).

**Copilot round 3 on HA-PR-#121 (2026-09-28).** The extractor read only `](target)`; angle-bracketed
(`](<target>)`), titled (`](target "title")`) and reference-definition (`[label]: target`) links were never
counted, and the header's "a drop in the checked count would show it" was a signal nothing enforced. The
guard now reads the three CommonMark forms through `extract_targets`, the header names them as the scope and
calls any fourth form a gap to extend rather than a signal, and the fixture proves each form resolving and
dangling. The live count is unchanged (404 of 2644): the mirrors carry none of the other two forms today.
