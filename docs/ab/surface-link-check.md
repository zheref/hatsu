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

## 2026-10-02 — green, and wired into CI (Hatsu v0.81.0, nen v0.18.2)

nen v0.17.0 re-aims every relative link for the depth its mirror lands at (zheref/nen#270, fixed by
zheref/nen#285, merged 2026-09-29), and the pin is v0.18.2. Run live at `origin/main` 143831bd:

```text
$ bash scripts/surface_link_check.sh --summary .
--- dangling links by surface · kind · link prefix
surface-link-check: every relative link under surfaces/ resolves (2931 checked).
```

With nothing left red, the step is no longer deferred: `surface-mirror-check.yml` runs
`.trusted/scripts/surface_link_check.sh "$PWD"` inside its existing **Surface-mirror drift check** step,
after the drift verdict. It lives inside that step rather than as a new one because
`scripts/workflow_runner_policy_check.rb` freezes the workflow's step names and order: a new step would
need the two-step landing (`docs/GATE-CONFIGURATION.md`), while a body change inside the frozen step is
accepted by `main`'s trusted validator as it stands (self-test and live run, both exit 0). Exit `1`
fails the check naming file, link and resolved path; any other exit fails it as a guard that could not
run; it never exits `3`, since it needs no nen. `pull_request_target` runs the default branch's
(`main`'s) workflow and `github.sha` is `main`'s tip, so `.trusted/` is `main`'s copy for every pull
request, a stacked one included, and the step takes effect on pull requests opened or updated after this
lands.

**Against #72's acceptance criteria**, box by box:

1. *The guard resolves every relative link and names file, link and resolved path* — met since #121; the
   fixture proves each form, and now also a file whose only link is a reference definition.
2. *It runs in CI beside surface-mirror-check, and locally by the same entry point* — met, read as
   **inside, not beside**: the guard runs in surface-mirror-check's own drift step (a new step would need
   the two-step landing), under the same `surface-mirror-check` context, and by hand as
   `bash scripts/surface_link_check.sh`.
3. *Exit codes 0 / 1 / 2 / 3* — met with **3 unused**: the guard needs no nen, so it never exits 3; the
   code stays reserved so the two guards read one table.
4. *The generator emits the correct depth; 0 dangling in this repository's half* — met by
   **supersession**: `scripts/antigravity_mirror_sync.sh` is retired, every mirror is
   `nen surface mirror generate`'s, and nen#285 fixed the depth (2931 of 2931 resolve).
5. *A companion nen issue filed and cross-referenced* — zheref/nen#270, closed by zheref/nen#285; both
   appear on #72's timeline.
6. *#71's regression cannot return (0 dangling in the antigravity skills)* — met: 0 dangling across every
   surface, and the fixture carries the nested-depth case.

**What hanten's round changed (2026-10-02).** Feitan (SEC-7): a file name carrying a newline split into
two names in the guard's line-delimited list, so a pull request could print a line starting `::` (a
forged workflow command) and hand the guard a path outside the checkout. The list is now NUL-delimited,
a name outside `surfaces/` or with a control character is refused at exit 2 and printed escaped, and the
step fences each guard's output between `::stop-commands::` and a fresh resume token. A link climbing
above the repository root is now folded as text and reported dangling without a stat. Nobunaga and Feitan: under `set -e`, a file with no inline link
ended extraction at the first `grep`, so its reference definitions were never judged (`0 checked`); each
grep is now guarded so a no-match is not fatal and a real failure still is, and the caller refuses a
file it could not extract. Each change has a fixture case that is red on the previous guard or on a
mutant of the new one.

**What Nobunaga's second pass changed (2026-10-02).** The claim above was stronger than the code: `..`
folding stopped a climb, but a committed symlink inside the checkout (`surfaces/codex/etcl -> /etc`, or
`docs/x -> /etc` beside an authored link) was still followed by the final `-e`, a one-bit "does this
path exist" answer about the runner. Each prefix of the folded path is now lstat'ed in turn and a path
through a symlink is reported dangling (`passes through a symlink; not checked`) without a stat, so the
guard cannot probe the runner's filesystem by either route. The fence now carries each guard's stderr
too (`2>&1`: the runner reads stdout and stderr on separate readers, so a late stderr line could land
after the resume token), and the token is printed after a newline so it starts a line. Both greps read
a file holding a NUL byte as text (`grep -a`; GNU grep 3.5 and later otherwise print nothing for a
"binary" file and exit 0, so its links would pass unjudged). A trailing `/` survives folding, so
`SKILL.md/` dangles as it did unfolded, and a fixture case pins that the folded path, never the
unfolded one, is the one judged. These fixes had no reviewer pass of their own; each has a fixture case
red on the previous guard or on a mutant of the new one.
