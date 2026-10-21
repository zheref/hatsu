#!/usr/bin/env bash
# Focused, declared verification for scripts/port_rule_reserve.sh (hatsu:bankai-rule § 3).
# Requires Bash, git, mktemp and jq (to check --json output parses). No network: `gh` is a stub
# this fixture writes onto PATH. Invoked only through `nen shu test --lane port-rule-guard --repo <hatsu>`.
#
# THE TWO-BRANCH CASE (zheref/hatsu#355 criterion 7): one tip carrying PT-1..PT-3; branch A adds
# PT-4 and is "open as a PR" through the stub; branch B reserves next and must get PT-5, never PT-4.
# THE FOUR READS (hanten, 2026-10-20): the run's own branch (HEAD and working tree, run against the
# run's WORKTREE while the clone root stays on main), a sibling pushed ports-* branch, a pruned
# deleted branch, and --check's duplicate pass. THE HOSTILE CASES (Feitan): a PR whose file list
# does not name the pair file is never read even when its diff carries a `+++ b/<pair>` content
# line; a PR that names it cannot smuggle that header line inside another file's hunk; a fork PR is
# listed and never counted, at the ceiling or out of shape; a same-repository id outside
# ^[1-9][0-9]{0,8}$ is a named refusal at exit 3; a short open-PR list or a short file list is exit
# 1 and reserves nothing; a `"` in a branch name still yields JSON that parses; a pair path with
# regex metacharacters, `..` or a leading `/` is usage (never spliced into a pattern); a symlinked working-tree pair file is
# refused; a flag with no value and an unresolvable or unfetchable tip are named exits.
# ONE GLOBAL COUNTER (the maintainer's ruling of 2026-10-21; docs/ROSTER.md § Rulings of
# 2026-10-21 — the port rule prefix (HA#355)): the next id exceeds every PT-<n> in every pair file of
# the rulings directory — two pair files at the tip, a sibling branch adding a third, an open PR adding
# a fourth, a file this run creates — a pair file with no rows yet takes the directory's next id, an
# empty directory starts at PT-1, and --check catches one id in two different pair files (against the
# tip, a sibling, a PR, or this branch's own second file); a pair file named out of shape in a counted
# place is a named refusal at exit 3.
# HANTEN ROUND 1 (S1-S9): a non-canonical rulings path is usage; the run's own push and own PR are not
# others to --check; a failed read (a missing blob, an unreadable file) is exit 1, never empty; a row's
# first cell is read with any padding; a fork PR is never read; a PR-checkout local head is skipped;
# --target and --prefix are checked; a foreign pair-file header and an out-of-shape name are exit 3.
# HANTEN ROUND 2 (T1-T6, T15): own is decided by ancestry (a same-named branch or PR of another run is
# counted), one id in two rows of one file is a duplicate, every GFM row form is counted and every
# look-alike refused, the header test is total (PR sections, indentation, key case, numbering value),
# a '.' remote is read and a refs/pull head skipped by count, JSON escapes control characters, a
# --target name is a segment, and the shipped template renders into a clean pair file.
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "port-rule-guard fixture: jq is required (the --json case parses the output)" >&2; exit 2; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$repo_root/scripts/port_rule_reserve.sh"
root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-port-rule-guard.XXXXXX")"
trap 'rm -rf "${root:?}"' EXIT
pass=0; total=0
check() { total=$((total+1)); if eval "$2"; then pass=$((pass+1)); echo "  ok    $1"; else echo "  FAIL  $1"; fi; }
g() { # git with a fixture identity, no global options on the command line
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.com GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.com git "$@"
}

# an "origin" with the tip, cloned as the authoring clone
origin="$root/origin"; clone="$root/clone"
g init -q -b main "$origin"
mkdir -p "$origin/handbooks/ports" "$origin/p"
pair=handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md
cat > "$origin/$pair" <<'MD'
<!-- pair: swiftui-tca-uzf-v2 -> compose-uzf-v2 · prefix: PT · numbering: global -->
| id | source | target | handling | rationale | date | supersedes |
|---|---|---|---|---|---|---|
| PT-1 | SW-3 | KT-2 | mirror | same shape | 2026-10-20 | |
| PT-2 | TCA Effect.run | Hilt repository call | map | effects become injected calls | 2026-10-20 | |
| PT-3 | SwiftUI .sheet | ModalBottomSheet | map | the idiom | 2026-10-20 | |
MD
printf '| PT-1 | a | b | mirror | x | 2026-10-20 | |\n' > "$origin/p/x.md"
printf 'q\n' > "$origin/q.md"
# the global case's own rulings directory: two pair files whose ids interleave, and an INDEX with no id rows
mkdir -p "$origin/global/ports"
printf '| PT-1 | SW-1 | KT-1 | mirror | x | 2026-10-21 | |\n| PT-4 | SW-4 | KT-4 | map | x | 2026-10-21 | |\n' > "$origin/global/ports/a--b.md"
printf '| PT-2 | RC-2 | KT-2 | mirror | x | 2026-10-21 | |\n| PT-3 | RC-3 | KT-3 | map | x | 2026-10-21 | |\n' > "$origin/global/ports/c--d.md"
printf '| From | To | File | Rulings | Last ruling |\n|---|---|---|---|---|\n| a | b | a--b.md | 2 | 2026-10-21 |\n' > "$origin/global/ports/INDEX.md"
g -C "$origin" add -A >/dev/null
g -C "$origin" commit -qm tip
g clone -q "$origin" "$clone"

# branch A: adds PT-4, served by the stub as open PR #7 (file list names the pair file)
g -C "$clone" switch -q -c a
printf '| PT-4 | SW-9 | none | drop with note | no twin | 2026-10-20 | |\n' >> "$clone/$pair"
g -C "$clone" commit -qam "A adds PT-4"
g -C "$clone" diff main..a > "$root/diff7.txt"
g -C "$clone" switch -q main

# a hostile diff: a PR touching only q.md whose added CONTENT carries a +++ b/<pair> line and a PT-50 row
cat > "$root/diff8.txt" <<EOF
diff --git a/q.md b/q.md
--- a/q.md
+++ b/q.md
@@ -1,1 +1,3 @@
 q
++++ b/$pair
+| PT-50 | x | y | mirror | smuggled | 2026-10-20 | |
EOF
# a hostile diff from a PR that DOES name the pair file: a typo fix in it, the smuggle inside q.md's hunk
cat > "$root/diff13.txt" <<EOF
diff --git a/$pair b/$pair
--- a/$pair
+++ b/$pair
@@ -1,1 +1,1 @@
-<!-- pair: swiftui-tca-uzf-v2 -> compose-uzf-v2 · prefix: PT -->
+<!-- pair: swiftui-tca-uzf-v2 -> compose-uzf-v2 · prefix: PT · numbering: global (typo fixed) -->
diff --git a/q.md b/q.md
--- a/q.md
+++ b/q.md
@@ -1,1 +1,3 @@
 q
++++ b/$pair
+| PT-77 | x | y | mirror | smuggled in q | 2026-10-20 | |
EOF
# an out-of-shape id in a PR that names the pair file
cat > "$root/diff9.txt" <<EOF
diff --git a/$pair b/$pair
--- a/$pair
+++ b/$pair
@@ -6,0 +7,2 @@
+| PT-010 | x | y | mirror | leading zero | 2026-10-20 | |
+| PT-9223372036854775807 | x | y | mirror | overflow | 2026-10-20 | |
EOF
# a fork PR at the ceiling
cat > "$root/diff14.txt" <<EOF
diff --git a/$pair b/$pair
--- a/$pair
+++ b/$pair
@@ -6,0 +7,1 @@
+| PT-999999999 | x | y | mirror | fork at the ceiling | 2026-10-20 | |
EOF
# a pure rename INTO the pair path (no hunks), and a deletion of the pair file
cat > "$root/diff15.txt" <<EOF
diff --git a/old.md b/$pair
similarity index 100%
rename from old.md
rename to $pair
EOF
cat > "$root/diff16.txt" <<EOF
diff --git a/$pair b/$pair
deleted file mode 100644
--- a/$pair
+++ /dev/null
@@ -1,6 +0,0 @@
-<!-- pair: swiftui-tca-uzf-v2 -> compose-uzf-v2 · prefix: PT -->
EOF
# a same-repository PR on a look-alike path
cat > "$root/diff11.txt" <<'EOF'
diff --git a/p/xxmd b/p/xxmd
--- a/p/xxmd
+++ b/p/xxmd
@@ -0,0 +1 @@
+| PT-8 | x | y | mirror | lookalike | 2026-10-20 | |
EOF

# the gh stub. STUB_PRS: lines "num<TAB>fork<TAB>ref<TAB>files(comma)<TAB>diff-file[<TAB>headRefOid]"; STUB_TOTAL overrides
# the search total; STUB_CHANGED overrides changedFiles for PR 7 (a short file list)
stub="$root/bin"; mkdir -p "$stub"
cat > "$stub/gh" <<'SH'
#!/usr/bin/env bash
prs() { printf '%b' "${STUB_PRS:-}"; }
case "$1 $2" in
  "api search/issues"*) if [ -n "${STUB_TOTAL:-}" ]; then echo "$STUB_TOTAL"; else prs | grep -c . || true; fi ;;
  "pr list") prs | awk -F'\t' -v ch="${STUB_CHANGED:-}" '{ n=split($4, a, ","); if (ch != "" && $1 == 7) n=ch; printf "%s\t%s\t%s\t%s\t%s\n", $1, $2, n, $3, $6 }' ;;
  "api --paginate") n="${3#repos/*/pulls/}"; n="${n%/files}"; prs | awk -F'\t' -v n="$n" '$1==n {gsub(",", "\n", $4); print $4}' ;;
  "pr diff") n="$3"; f="$(prs | awk -F'\t' -v n="$n" '$1==n {print $5}')"; if [ -n "$f" ] && [ -f "$f" ]; then cat "$f"; else exit 1; fi ;;
  *) exit 2 ;;
esac
SH
chmod +x "$stub/gh"
export PATH="$stub:$PATH"
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n"

set +e
g -C "$clone" switch -q -c b
out="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"; rc=$?
check "branch B reserves PT-5 past branch A's open PT-4 (exit $rc)" '[ "$rc" = 0 ] && printf "%s" "$out" | grep -q "^next: PT-5$"'
check "the tip's three and PR #7's one are all seen" 'printf "%s" "$out" | grep -q "PT-3 tip origin/main" && printf "%s" "$out" | grep -q "PT-4 PR #7 (a)"'
outj="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT --json)"
check "--json carries complete, next and number and parses" 'printf "%s" "$outj" | jq -e ".complete == true and .next == \"PT-5\" and .number == 5" >/dev/null'
g -C "$clone" switch -q a
outa="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"
check "from branch A the same answer, PT-5: its own PT-4 is the open PR's, the tip is main" 'printf "%s" "$outa" | grep -q "^next: PT-5$"'
g -C "$clone" switch -q main

# the run's own branch: a second ruling on one unpushed branch with no PR never repeats the first
export STUB_PRS=""
g -C "$clone" switch -q -c fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-run1
first="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT | head -1)"
printf '| PT-4 | SW-10 | KT-7 | map | first of the run | 2026-10-20 | |\n' >> "$clone/$pair"
second_wt="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT | head -1)"
g -C "$clone" commit -qam "run1 adds PT-4"
second="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"
check "the run's own branch counts: PT-4 first, then PT-5 from the working tree and from HEAD" '[ "$first" = "next: PT-4" ] && [ "$second_wt" = "next: PT-5" ] && printf "%s" "$second" | grep -q "^next: PT-5$" && printf "%s" "$second" | grep -q "PT-4 branch HEAD"'
# a sibling run's pushed rulings branch (no PR yet) is read through its remote ref
g -C "$clone" push -q origin fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-run1
g -C "$clone" switch -q main
g -C "$clone" switch -q -c opus/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-run2
sib="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"
check "a sibling run's pushed ports-* branch with no PR is read: PT-5 past its PT-4" 'printf "%s" "$sib" | grep -q "^next: PT-5$" && printf "%s" "$sib" | grep -q "PT-4 branch origin/fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-run1"'
# the run's rulings WORKTREE (the skill's wiring): the clone root stays on main, the worktree holds the unpushed row
wt="$clone/.nen/worktrees/claude-code/ports-run3"
g -C "$clone" switch -q main
g -C "$clone" worktree add -q -b sonnet/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-run3 "$wt" main
printf '| PT-5 | SW-11 | KT-9 | map | worktree row | 2026-10-20 | |\n' >> "$wt/$pair"
outw="$(bash "$guard" --worktree "$wt" --target acme/widget --pair-file "$pair" --prefix PT)"
check "run against the run's worktree (clone root on main): its own unpushed PT-5 is seen, next PT-6" 'printf "%s" "$outw" | grep -q "^next: PT-6$" && printf "%s" "$outw" | grep -q "PT-5 working tree"'
# --check: a duplicate between this branch and a sibling pushed branch is exit 3; no duplicate is exit 0
printf '%s\n' "$(sed 's/| PT-5 | SW-11/| PT-4 | SW-11/' "$wt/$pair")" > "$wt/$pair"
bash "$guard" --worktree "$wt" --target acme/widget --pair-file "$pair" --prefix PT --check >/dev/null 2>"$root/ec.txt"; rcck=$?
check "--check: an id this branch adds that a sibling branch carries is exit 3, naming both" '[ "$rcck" = 3 ] && grep -qF "PT-4 ($pair) also at branch origin/fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-run1 ($pair)" "$root/ec.txt"'
printf '%s\n' "$(sed 's/| PT-4 | SW-11/| PT-5 | SW-11/' "$wt/$pair")" > "$wt/$pair"
bash "$guard" --worktree "$wt" --target acme/widget --pair-file "$pair" --prefix PT --check >/dev/null 2>&1; rcok=$?
check "--check: no duplicate is exit 0" '[ "$rcok" = 0 ]'
# a symlinked working-tree pair file is refused
mv "$wt/$pair" "$root/elsewhere.md"; ln -s "$root/elsewhere.md" "$wt/$pair"
bash "$guard" --worktree "$wt" --target acme/widget --pair-file "$pair" --prefix PT >/dev/null 2>&1; rcl=$?
check "a symlinked working-tree pair file is refused at exit 2" '[ "$rcl" = 2 ]'
g -C "$clone" worktree remove --force "$wt"
# a deleted sibling branch stops counting after the pruned fetch
g -C "$clone" push -q origin --delete fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-run1
g -C "$clone" branch -q -D fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-run1
outp="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"
check "a sibling branch deleted on origin (and locally) is pruned and stops counting (next PT-4)" 'printf "%s" "$outp" | grep -q "^next: PT-4$" && ! printf "%s" "$outp" | grep -q "origin/fable/kurapika/ports-"'
g -C "$clone" switch -q main
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n"

outn="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file handbooks/ports/react-uzf-v1--compose-uzf-v2.md --prefix PT)"; rcn=$?
check "a pair file absent at the tip and in every PR takes the directory's next id, PT-5, never PT-1 (exit $rcn)" '[ "$rcn" = 0 ] && printf "%s" "$outn" | grep -q "^next: PT-5$"'
oute="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file fresh/ports/a--b.md --prefix PT)"; rce=$?
check "an empty rulings directory starts the counter at PT-1 (exit $rce)" '[ "$rce" = 0 ] && printf "%s" "$oute" | grep -q "^next: PT-1$"'

# hostile: a PR whose files do not name the pair file is never read, whatever its diff text says
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n8\ttrue\tevil\tq.md\t$root/diff8.txt\n"
outh="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"; rch=$?
check "a PR not touching the pair file is never read, even with a +++ b/<pair> content line (exit $rch)" '[ "$rch" = 0 ] && printf "%s" "$outh" | grep -q "^next: PT-5$" && ! printf "%s" "$outh" | grep -q "PT-50"'
# hostile: a same-repo PR naming the pair file cannot smuggle the header inside another file's hunk
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n13\tfalse\tsmuggle\t$pair,q.md\t$root/diff13.txt\n"
outs="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"; rcs13=$?
check "a header line inside another file's hunk is never a header: PT-77 not seen, next PT-5" '[ "$rcs13" = 0 ] && printf "%s" "$outs" | grep -q "^next: PT-5$" && ! printf "%s" "$outs" | grep -q "PT-77"'
# a PR that names the pair file with no hunk header for it (a rename) is unread; a deletion is read as empty
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n15\tfalse\tren\t$pair\t$root/diff15.txt\n"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT >/dev/null 2>"$root/e15.txt"; rc15=$?
check "a PR naming the pair file with no hunk header (a rename) is exit 1, named, never read as empty" '[ "$rc15" = 1 ] && grep -qF "PR #15 names the pair file $pair but its diff carries no hunk header" "$root/e15.txt"'
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n16\tfalse\tdel\t$pair\t$root/diff16.txt\n"
out16="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"; rc16=$?
check "a PR deleting the pair file is read as empty, exit 0" '[ "$rc16" = 0 ] && printf "%s" "$out16" | grep -q "^next: PT-5$"'
# a local sibling ports-* head in the same clone (another run authoring there, unpushed) is read
export STUB_PRS=""
g -C "$clone" switch -q -c fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-local
printf '| PT-4 | SW-12 | KT-1 | map | local sibling | 2026-10-20 | |\n' >> "$clone/$pair"
g -C "$clone" commit -qam "local sibling adds PT-4"
g -C "$clone" switch -q main
g -C "$clone" switch -q -c gpt/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-mine
outls="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"
check "a local, unpushed sibling ports-* head in the same clone is read: PT-5 past its PT-4" 'printf "%s" "$outls" | grep -q "^next: PT-5$" && printf "%s" "$outls" | grep -q "PT-4 branch fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-local"'
g -C "$clone" switch -q main
g -C "$clone" branch -q -D fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-local gpt/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-mine
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n"
# a --single-branch clone cannot see siblings: refused
g clone -q --single-branch --branch main "$origin" "$root/single"
bash "$guard" --worktree "$root/single" --target acme/widget --pair-file "$pair" --prefix PT >/dev/null 2>"$root/esb.txt"; rcsb=$?
check "a clone whose fetch refspec does not cover refs/heads/* is refused at exit 2" '[ "$rcsb" = 2 ] && grep -q "fetch refspec does not cover" "$root/esb.txt"'
# hostile: a same-repo out-of-shape id is a named refusal at exit 3
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n9\tfalse\tbad\t$pair\t$root/diff9.txt\n"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT >"$root/o3.txt" 2>"$root/e3.txt"; rc3=$?
check "a same-repo id with a leading zero or past the ceiling is a named refusal at exit 3, listing the PR (exit $rc3)" '[ "$rc3" = 3 ] && grep -q "PT-010 PR #9 (bad)" "$root/e3.txt" && grep -q "PT-9223372036854775807 PR #9" "$root/e3.txt"'
# hostile: a FORK PR's ids are listed and never counted, at the ceiling or out of shape
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n14\ttrue\tforkmax\t$pair\t$root/diff14.txt\n9\ttrue\tforkbad\t$pair\t$root/diff9.txt\n"
outf="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"; rcf2=$?
check "a fork PR at the ceiling or out of shape is listed as not read, by number only, and never moves the id (exit $rcf2)" '[ "$rcf2" = 0 ] && printf "%s" "$outf" | grep -q "^next: PT-5$" && printf "%s" "$outf" | grep -q "PR #14 fork, not read" && printf "%s" "$outf" | grep -q "PR #9 fork, not read" && ! printf "%s" "$outf" | grep -qE "forkmax|PT-999999999"'
# hostile: a short open-PR list is exit 1
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n"
STUB_TOTAL=5 bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT >/dev/null 2>"$root/e1.txt"; rcs=$?
check "an open-PR list shorter than the repository's open total is exit 1" '[ "$rcs" = 1 ] && grep -q "short (1 read of 5 open)" "$root/e1.txt"'
# hostile: a short file list is exit 1
STUB_CHANGED=200 bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT >/dev/null 2>"$root/e2.txt"; rcfl=$?
check "a PR file list shorter than its changedFiles is exit 1, never clean" '[ "$rcfl" = 1 ] && grep -q "file list is short (1 read of 200 changed)" "$root/e2.txt"'
# an unreadable diff is exit 1 and reserves nothing
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n12\tfalse\tc\t$pair\t$root/missing.txt\n"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT >/dev/null 2>&1; rcu=$?
check "an unreadable open PR diff is exit 1, never clean, and reserves nothing" '[ "$rcu" = 1 ]'
outu="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT --json 2>/dev/null)"
check "an incomplete read prints complete:false and a null next" 'printf "%s" "$outu" | jq -e ".complete == false and .next == null" >/dev/null'
# a quote in a branch name still yields JSON that parses
export STUB_PRS="7\tfalse\tevil\"x\t$pair\t$root/diff7.txt\n"
outq="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT --json)"
check "a quote in a branch name is escaped in --json" 'printf "%s" "$outq" | jq -e ".seen | map(select(test(\"evil\\\"x\"))) | length == 1" >/dev/null'
# the pair path: metacharacters are usage; a look-alike path never matches
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "p/c(1).md" --prefix PT >/dev/null 2>&1; rcm=$?
check "a pair path with regex metacharacters is refused as usage, never spliced into a pattern" '[ "$rcm" = 2 ]'
export STUB_PRS="11\tfalse\tl\tp/xxmd\t$root/diff11.txt\n"
outx="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "p/x.md" --prefix PT)"
check "p/x.md never reads p/xxmd (the tip's PT-1 only, next PT-2)" 'printf "%s" "$outx" | grep -q "^next: PT-2$"'
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "../x.md" --prefix PT >/dev/null 2>&1; rcd=$?
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "/etc/x.md" --prefix PT >/dev/null 2>&1; rca=$?
check "a pair path with .. or a leading / is usage" '[ "$rcd" = 2 ] && [ "$rca" = 2 ]'
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix 'P T' >/dev/null 2>&1; rcp=$?
check "a prefix with a space is usage" '[ "$rcp" = 2 ]'
bash "$guard" --worktree "$root/nowhere" --target acme/widget --pair-file "$pair" --prefix PT >/dev/null 2>&1; rcc=$?
check "a worktree that is not a git checkout is exit 2" '[ "$rcc" = 2 ]'
bash "$guard" --bogus >/dev/null 2>&1; rcb=$?
check "an unknown argument is exit 2" '[ "$rcb" = 2 ]'
bash "$guard" --worktree >/dev/null 2>&1; rcv=$?
check "a flag with no value is usage, never an unbound-variable crash" '[ "$rcv" = 2 ]'
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "x.md" --prefix PT >/dev/null 2>&1; rcnd=$?
check "a pair path with no directory is usage: the counter is the rulings directory's" '[ "$rcnd" = 2 ]'

# ONE GLOBAL COUNTER: two pair files at the tip (PT-1..PT-4 interleaved), a sibling branch adding PT-6 to a
# third file, an open same-repository PR adding PT-8 to a fourth, a fork PR's PT-50 listed and never counted
gp=global/ports
g -C "$clone" switch -q -c opus/kurapika/ports-e--f-run9
printf '| PT-6 | SW-6 | KT-6 | map | sibling, third file | 2026-10-21 | |\n' > "$clone/$gp/e--f.md"
g -C "$clone" add "$gp/e--f.md"; g -C "$clone" commit -qm "sibling adds PT-6 in e--f"
g -C "$clone" push -q origin opus/kurapika/ports-e--f-run9
g -C "$clone" switch -q main
g -C "$clone" branch -q -D opus/kurapika/ports-e--f-run9
cat > "$root/diff21.txt" <<EOF
diff --git a/$gp/g--h.md b/$gp/g--h.md
new file mode 100644
--- /dev/null
+++ b/$gp/g--h.md
@@ -0,0 +1,1 @@
+| PT-8 | RC-8 | KT-8 | map | open PR, fourth file | 2026-10-21 | |
EOF
cat > "$root/diff22.txt" <<EOF
diff --git a/$gp/k--l.md b/$gp/k--l.md
new file mode 100644
--- /dev/null
+++ b/$gp/k--l.md
@@ -0,0 +1,1 @@
+| PT-50 | RC-9 | KT-9 | map | fork | 2026-10-21 | |
EOF
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n21\tfalse\tgh21\t$gp/g--h.md\t$root/diff21.txt\n22\ttrue\tfk22\t$gp/k--l.md\t$root/diff22.txt\n"
g -C "$clone" switch -q -c sonnet/kurapika/ports-a--b-run10
outg="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT)"; rcg=$?
check "global: the next id exceeds every pair file's -- the tip's two, a sibling's third, a PR's fourth: PT-9 (exit $rcg)" '[ "$rcg" = 0 ] && printf "%s" "$outg" | grep -q "^next: PT-9$"'
check "global: every read is named with its file" 'printf "%s" "$outg" | grep -qF "PT-4 tip origin/main in $gp/a--b.md" && printf "%s" "$outg" | grep -qF "PT-3 tip origin/main in $gp/c--d.md" && printf "%s" "$outg" | grep -qF "PT-6 branch origin/opus/kurapika/ports-e--f-run9 in $gp/e--f.md" && printf "%s" "$outg" | grep -qF "PT-8 PR #21 (gh21) in $gp/g--h.md" && printf "%s" "$outg" | grep -qF "PR #22 fork, not read" && ! printf "%s" "$outg" | grep -q "PT-50"'
outgj="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/i--j.md" --prefix PT --json)"
check "global: a pair with no file yet takes the same PT-9, never PT-1 (--json parses)" 'printf "%s" "$outgj" | jq -e ".complete == true and .next == \"PT-9\" and .number == 9" >/dev/null'
printf '| PT-9 | RC-1 | SW-1 | map | a file this run creates | 2026-10-21 | |\n' > "$clone/$gp/m--n.md"
outgw="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT)"
check "global: a pair file this run creates in its working tree counts: next PT-10" 'printf "%s" "$outgw" | grep -q "^next: PT-10$" && printf "%s" "$outgw" | grep -qF "PT-9 working tree in $gp/m--n.md"'
# --check across pair files
gck() { bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT --check >/dev/null 2>"$root/gck.txt"; }
printf '| PT-10 | SW-10 | KT-10 | map | same id, second file | 2026-10-21 | |\n' >> "$clone/$gp/a--b.md"
printf '| PT-10 | RC-10 | SW-10 | map | same id, first file | 2026-10-21 | |\n' >> "$clone/$gp/m--n.md"
gck; rcg1=$?
check "global --check: one id in two of this branch's own pair files is exit 3, naming both files" '[ "$rcg1" = 3 ] && grep -qF "PT-10 ($gp/a--b.md) also at working tree ($gp/m--n.md)" "$root/gck.txt"'
g -C "$clone" checkout -q -- "$gp/a--b.md"; rm -f "$clone/$gp/m--n.md"
printf '| PT-6 | SW-60 | KT-60 | map | collides with the sibling | 2026-10-21 | |\n' >> "$clone/$gp/a--b.md"
gck; rcg2=$?
check "global --check: an id a sibling branch carries in a DIFFERENT pair file is exit 3" '[ "$rcg2" = 3 ] && grep -qF "PT-6 ($gp/a--b.md) also at branch origin/opus/kurapika/ports-e--f-run9 ($gp/e--f.md)" "$root/gck.txt"'
g -C "$clone" checkout -q -- "$gp/a--b.md"
printf '| PT-2 | SW-20 | KT-20 | map | collides with the tip, other file | 2026-10-21 | |\n' >> "$clone/$gp/a--b.md"
gck; rcg3=$?
check "global --check: an id the tip carries in a DIFFERENT pair file is exit 3, never skipped as a merged row" '[ "$rcg3" = 3 ] && grep -qF "PT-2 ($gp/a--b.md) also at tip origin/main ($gp/c--d.md)" "$root/gck.txt"'
g -C "$clone" checkout -q -- "$gp/a--b.md"
printf '| PT-8 | SW-80 | KT-80 | map | collides with the open PR | 2026-10-21 | |\n' >> "$clone/$gp/a--b.md"
gck; rcg4=$?
check "global --check: an id an open PR adds to a DIFFERENT pair file is exit 3" '[ "$rcg4" = 3 ] && grep -qF "PT-8 ($gp/a--b.md) also at PR #21 (gh21) ($gp/g--h.md)" "$root/gck.txt"'
g -C "$clone" checkout -q -- "$gp/a--b.md"
printf '| PT-9 | SW-90 | KT-90 | map | its own | 2026-10-21 | |\n' >> "$clone/$gp/a--b.md"
gck; rcg5=$?
check "global --check: the reserved PT-9 beside the tip's carried rows is no duplicate, exit 0" '[ "$rcg5" = 0 ]'
g -C "$clone" checkout -q -- "$gp/a--b.md"
# hostile: a same-repository PR naming a pair file out of shape is a named refusal; a fork's is ignored
export STUB_PRS="23\tfalse\tbadname\t$gp/bad name.md\t$root/diff21.txt\n"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT >/dev/null 2>"$root/e23.txt"; rc23=$?
check "global: a same-repository PR naming a pair file out of shape is a named refusal at exit 3" '[ "$rc23" = 3 ] && grep -q "pair file named outside" "$root/e23.txt" && grep -q "PR #23 (badname)" "$root/e23.txt"'
export STUB_PRS="24\ttrue\tbadfork\t$gp/bad name.md\t$root/diff21.txt\n"
outbf="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT)"; rc24=$?
check "global: a fork PR naming a pair file out of shape is never read, exit 0, PT-7 past the sibling's PT-6" '[ "$rc24" = 0 ] && printf "%s" "$outbf" | grep -q "^next: PT-7$"'
g -C "$clone" switch -q main
g -C "$clone" branch -q -D sonnet/kurapika/ports-a--b-run10

# HANTEN ROUND 1 (2026-10-21): the settlements S1-S9, each a row
# S1: a non-canonical rulings path is usage, never a quieter read
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "handbooks//ports/x.md" --prefix PT >/dev/null 2>&1; rcs1a=$?
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "./handbooks/ports/x.md" --prefix PT >/dev/null 2>&1; rcs1b=$?
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "handbooks/./ports/x.md" --prefix PT >/dev/null 2>&1; rcs1c=$?
check "S1: a pair path with '//', a leading './' or a '/./' segment is usage, exit 2 (got $rcs1a $rcs1b $rcs1c)" '[ "$rcs1a" = 2 ] && [ "$rcs1b" = 2 ] && [ "$rcs1c" = 2 ]'
# S7: --target is owner/name in shape
bash "$guard" --worktree "$clone" --target 'acme/w;x' --pair-file "$pair" --prefix PT >/dev/null 2>&1; rcs7a=$?
bash "$guard" --worktree "$clone" --target 'a/b/c' --pair-file "$pair" --prefix PT >/dev/null 2>&1; rcs7b=$?
check "S7: a --target outside owner/name's shape is usage, exit 2" '[ "$rcs7a" = 2 ] && [ "$rcs7b" = 2 ]'
# S8: the prefix is the ruled one
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix KT >/dev/null 2>"$root/es8.txt"; rcs8a=$?
check "S8: a --prefix other than PT is usage, exit 2, named" '[ "$rcs8a" = 2 ] && grep -q "is PT, the ruled prefix" "$root/es8.txt"'
export STUB_PRS=""
# S2: the run's own push and its own PR are never "others" to --check
g -C "$clone" switch -q -c haiku/kurapika/ports-own-run11
printf '| PT-20 | SW-20 | KT-20 | map | the run own | 2026-10-21 | |\n' >> "$clone/$gp/a--b.md"
g -C "$clone" commit -qam "own run adds PT-20"
g -C "$clone" push -q origin haiku/kurapika/ports-own-run11
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT --check >/dev/null 2>"$root/es2a.txt"; rcs2a=$?
check "S2: --check after the run's own push is exit 0, its pushed copy never a sibling" '[ "$rcs2a" = 0 ]'
g -C "$clone" diff main..HEAD > "$root/diff40.txt"
g -C "$clone" push -q origin --delete haiku/kurapika/ports-own-run11
export STUB_PRS="40\tfalse\thaiku/kurapika/ports-own-run11\t$gp/a--b.md\t$root/diff40.txt\t$(g -C "$clone" rev-parse HEAD)\n"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT --check >/dev/null 2>&1; rcs2b=$?
check "S2: --check with only the run's own PR open (its headRefOid an ancestor of HEAD) is exit 0" '[ "$rcs2b" = 0 ]'
export STUB_PRS=""
g -C "$clone" switch -q main
g -C "$clone" branch -q -D haiku/kurapika/ports-own-run11
# S3: a failed read is unread, never empty -- a sibling's missing blob, and a working-tree file at mode 000
g -C "$clone" switch -q -c fable/kurapika/ports-blob-run12
printf '| PT-30 | SW-30 | KT-30 | map | blob soon gone | 2026-10-21 | |\n' > "$clone/$gp/o--p.md"
g -C "$clone" add "$gp/o--p.md"; g -C "$clone" commit -qm "sibling adds PT-30"
blob="$(g -C "$clone" rev-parse "HEAD:$gp/o--p.md")"
g -C "$clone" switch -q main
rm -f "${clone:?}/.git/objects/${blob:0:2}/${blob:2}"
outs3a="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT --json 2>"$root/es3a.txt")"; rcs3a=$?
check "S3: a sibling whose blob is missing is exit 1, named, complete:false and a null next" '[ "$rcs3a" = 1 ] && grep -q "o--p.md could not be read" "$root/es3a.txt" && printf "%s" "$outs3a" | jq -e ".complete == false and .next == null" >/dev/null'
g -C "$clone" branch -q -D fable/kurapika/ports-blob-run12
g -C "$clone" switch -q -c fable/kurapika/ports-mode-run13
printf '| PT-31 | SW-31 | KT-31 | map | unreadable | 2026-10-21 | |\n' > "$clone/$gp/q--r.md"
chmod 000 "$clone/$gp/q--r.md"
outs3b="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT --json 2>"$root/es3b.txt")"; rcs3b=$?
chmod 644 "$clone/$gp/q--r.md"; rm -f "${clone:?}/${gp:?}/q--r.md"
check "S3: a working-tree pair file at mode 000 is exit 1, named, complete:false and a null next" '[ "$rcs3b" = 1 ] && grep -q "q--r.md could not be read" "$root/es3b.txt" && printf "%s" "$outs3b" | jq -e ".complete == false and .next == null" >/dev/null'
# S8: a pair file declaring a foreign header is a named refusal
printf '<!-- pair: s -> t · prefix: KT · numbering: per pair file -->\n| KT-1 | a | b | map | x | 2026-10-21 | |\n' > "$clone/$gp/s--t.md"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT >/dev/null 2>"$root/es8b.txt"; rcs8b=$?
printf '<!-- pair: s -> t · prefix: PT · numbering: per pair file -->\n' > "$clone/$gp/s--t.md"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT >/dev/null 2>"$root/es8c.txt"; rcs8c=$?
rm -f "${clone:?}/${gp:?}/s--t.md"
check "S8: a pair file whose header declares a foreign prefix or numbering is exit 3, named" '[ "$rcs8b" = 3 ] && [ "$rcs8c" = 3 ] && grep -q "header is not .prefix: PT · numbering: global.*s--t.md" "$root/es8b.txt" && grep -q "s--t.md" "$root/es8c.txt"'
# S9: an out-of-shape name in the working tree and on a sibling is exit 3, the path printed
printf '| PT-32 | a | b | map | x | 2026-10-21 | |\n' > "$clone/$gp/bad name.md"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT >/dev/null 2>"$root/es9a.txt"; rcs9a=$?
check "S9: a working-tree pair file named out of shape is exit 3, its path named" '[ "$rcs9a" = 3 ] && grep -qF "bad\\ name.md in the working tree" "$root/es9a.txt"'
g -C "$clone" add "$gp/bad name.md"; g -C "$clone" commit -qm "sibling with an out-of-shape name"
g -C "$clone" switch -q main
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT >/dev/null 2>"$root/es9b.txt"; rcs9b=$?
check "S9: a sibling's pair file named out of shape is exit 3, its path and branch named" '[ "$rcs9b" = 3 ] && grep -qF "bad\\ name.md at branch fable/kurapika/ports-mode-run13" "$root/es9b.txt"'
g -C "$clone" branch -q -D fable/kurapika/ports-mode-run13
# S6: a local ports-* head that is a PR checkout or tracks another remote is skipped, named
g -C "$clone" switch -q -c x/y/ports-prcheckout
printf '| PT-90 | a | b | map | a PR checkout | 2026-10-21 | |\n' > "$clone/$gp/u--v.md"
g -C "$clone" add "$gp/u--v.md"; g -C "$clone" commit -qm "pr checkout"
g -C "$clone" switch -q main
g -C "$clone" branch -q -c x/y/ports-prcheckout x/y/ports-otherremote
g -C "$clone" config branch.x/y/ports-prcheckout.remote origin
g -C "$clone" config branch.x/y/ports-prcheckout.merge refs/pull/5/head
g -C "$clone" config branch.x/y/ports-otherremote.remote upstream
g -C "$clone" config branch.x/y/ports-otherremote.merge refs/heads/main
outs6="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT 2>"$root/es6.txt")"; rcs6=$?
check "S6: a local head tracking refs/pull/* or a remote whose URL is not origin's is skipped, counted by reason, never named or counted (next PT-7)" '[ "$rcs6" = 0 ] && printf "%s" "$outs6" | grep -q "^next: PT-7$" && grep -q "skipped 1 local ports-\* head(s) tracking refs/pull" "$root/es6.txt" && grep -q "skipped 1 local ports-\* head(s) tracking a remote whose URL is not origin" "$root/es6.txt" && ! grep -q "x/y/ports-" "$root/es6.txt"'
g -C "$clone" branch -q -D x/y/ports-prcheckout x/y/ports-otherremote
# S5: a fork PR is never read -- a mode-change diff, an unreadable diff, a short file list: exit 0, next unchanged
export STUB_PRS="7\ttrue\tf7\t$pair\t$root/diff15.txt\n31\ttrue\tf31\t$pair\t$root/missing.txt\n32\ttrue\tf32\t$pair\t$root/diff15.txt\n"
outs5="$(STUB_CHANGED=200 bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT 2>&1)"; rcs5=$?
check "S5: fork PRs with a mode-change diff, an unreadable diff and a short file list are listed, never read: exit 0, next PT-4" '[ "$rcs5" = 0 ] && printf "%s" "$outs5" | grep -q "^next: PT-4$" && printf "%s" "$outs5" | grep -q "PR #7 fork, not read" && printf "%s" "$outs5" | grep -q "PR #31 fork, not read" && ! printf "%s" "$outs5" | grep -q "f31"'
export STUB_PRS=""
# S4: a merged row with any cell padding is counted
printf '|PT-40|SW-40|KT-40|map|tight|2026-10-21||\n|  PT-41  |  SW-41 | KT-41 | map | wide | 2026-10-21 | |\n' >> "$origin/$gp/c--d.md"
g -C "$origin" commit -qam "hand-tightened rows"
outs4="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT)"; rcs4=$?
check "S4: tip rows '|PT-40|' and '|  PT-41  |' are counted: next PT-42" '[ "$rcs4" = 0 ] && printf "%s" "$outs4" | grep -q "^next: PT-42$"'

# HANTEN ROUND 2 (2026-10-21): the settlements T1-T6 and T15, each a row (the global next is PT-42 here)
export STUB_PRS=""
# T1: "own" is decided by ancestry, never by name. Another run pushed a same-named branch and opened its PR
g -C "$clone" switch -q -c haiku/kurapika/ports-same-run14
printf '| PT-50 | SW-50 | KT-50 | map | the other run | 2026-10-21 | |\n' >> "$clone/$gp/a--b.md"
g -C "$clone" commit -qam "another run adds PT-50"
othersha="$(g -C "$clone" rev-parse HEAD)"
g -C "$clone" push -q origin haiku/kurapika/ports-same-run14
g -C "$clone" diff main..HEAD > "$root/diff41.txt"
g -C "$clone" switch -q main
g -C "$clone" branch -q -D haiku/kurapika/ports-same-run14
g -C "$clone" switch -q --no-track -c haiku/kurapika/ports-same-run14 main
outt1="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT)"; rct1=$?
check "T1: a same-named pushed branch that is not an ancestor of HEAD is a sibling: its PT-50 is counted, next PT-51" '[ "$rct1" = 0 ] && printf "%s" "$outt1" | grep -q "^next: PT-51$" && printf "%s" "$outt1" | grep -qF "PT-50 branch origin/haiku/kurapika/ports-same-run14 in $gp/a--b.md"'
printf '| PT-50 | SW-51 | KT-51 | map | this run | 2026-10-21 | |\n' >> "$clone/$gp/a--b.md"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT --check >/dev/null 2>"$root/et1a.txt"; rct1a=$?
check "T1: --check catches this run's PT-50 against the same-named branch's PT-50, exit 3" '[ "$rct1a" = 3 ] && grep -qF "PT-50 ($gp/a--b.md) also at branch origin/haiku/kurapika/ports-same-run14" "$root/et1a.txt"'
g -C "$clone" push -q origin --delete haiku/kurapika/ports-same-run14
export STUB_PRS="41\tfalse\thaiku/kurapika/ports-same-run14\t$gp/a--b.md\t$root/diff41.txt\t$othersha\n"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT --check >/dev/null 2>"$root/et1b.txt"; rct1b=$?
check "T1: a same-named PR whose headRefOid is not an ancestor of HEAD is read as an open PR: --check exit 3" '[ "$rct1b" = 3 ] && grep -qF "PT-50 ($gp/a--b.md) also at PR #41" "$root/et1b.txt"'
export STUB_PRS=""
g -C "$clone" checkout -q -- "$gp/a--b.md"
# T1: one id in two rows of one pair file in this run's own place is a duplicate
printf '| PT-60 | SW-60 | KT-60 | map | first | 2026-10-21 | |\n| PT-60 | SW-61 | KT-61 | map | second | 2026-10-21 | |\n' >> "$clone/$gp/a--b.md"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT --check >/dev/null 2>"$root/et1c.txt"; rct1c=$?
check "T1: one id in two rows of the same pair file is a --check duplicate, exit 3" '[ "$rct1c" = 3 ] && grep -qF "PT-60 ($gp/a--b.md) also at a second row of the same file (working tree)" "$root/et1c.txt"'
g -C "$clone" checkout -q -- "$gp/a--b.md"
# T2: every GFM row form is counted, every look-alike refused by name
rowcase() { # $1 the line, then the expectation is read by the caller from $rcr and $outr
  printf '%s\n' "$1" > "$clone/$gp/w--x.md"
  outr="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT 2>"$root/er.txt")"; rcr=$?
  rm -f "${clone:?}/${gp:?}/w--x.md"
}
rowcase 'PT-70 | a | b | map | pipe-less | 2026-10-21 | |'; r1="$rcr $(printf '%s' "$outr" | head -1)"
rowcase '   | PT-70 | a | b | map | three spaces | 2026-10-21 | |'; r2="$rcr $(printf '%s' "$outr" | head -1)"
rowcase '| **PT-70** | a | b | map | bold | 2026-10-21 | |'; r3="$rcr $(printf '%s' "$outr" | head -1)"
rowcase '| `PT-70` | a | b | map | code | 2026-10-21 | |'; r4="$rcr $(printf '%s' "$outr" | head -1)"
rowcase '| *PT-70* | a | b | map | emphasis | 2026-10-21 | |'; r5="$rcr $(printf '%s' "$outr" | head -1)"
check "T2: a pipe-less row, a three-space indent, bold, code and emphasis first cells are each counted: next PT-71 ($r1 / $r2 / $r3 / $r4 / $r5)" '[ "$r1" = "0 next: PT-71" ] && [ "$r2" = "0 next: PT-71" ] && [ "$r3" = "0 next: PT-71" ] && [ "$r4" = "0 next: PT-71" ] && [ "$r5" = "0 next: PT-71" ]'
rowcase '    | PT-70 | a | b | map | four spaces | 2026-10-21 | |'; q1=$rcr; grep -q "indented past three spaces" "$root/er.txt" || q1=x
rowcase '| ~~PT-70~~ | a | b | map | struck | 2026-10-21 | |'; q2=$rcr; grep -q "not a counted row" "$root/er.txt" || q2=x
rowcase '| PT-70a | a | b | map | suffix | 2026-10-21 | |'; q3=$rcr; grep -q "not a counted row" "$root/er.txt" || q3=x
rowcase '| SW-3 | a | b | map | another prefix | 2026-10-21 | |'; q4=$rcr; grep -q "another prefix, SW-3 (a handbook-question)" "$root/er.txt" || q4=x
check "T2: a row indented four spaces, a struck or suffixed PT cell, and another prefix's first cell are each a named exit 3 ($q1 $q2 $q3 $q4)" '[ "$q1" = 3 ] && [ "$q2" = 3 ] && [ "$q3" = 3 ] && [ "$q4" = 3 ]'
rowcase '| id | source | target | handling | rationale | date | supersedes |'; h1="$rcr $(printf '%s' "$outr" | head -1)"
rowcase '|---|---|---|---|---|---|---|'; h2="$rcr $(printf '%s' "$outr" | head -1)"
check "T2: the header row and the separator row are not rows (next PT-42)" '[ "$h1" = "0 next: PT-42" ] && [ "$h2" = "0 next: PT-42" ]'
printf '| PT-1 | a | b | map | x | 2026-10-21 | |\n```\n|PT-80| example |\n```\n' > "$clone/$gp/w--x.md"
outfence="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT | head -1)"
rm -f "${clone:?}/${gp:?}/w--x.md"
check "T2: a row inside a fenced example is counted too, the documented safe over-count (next PT-81)" '[ "$outfence" = "next: PT-81" ]'
# T3: the header refusal is total -- every variant below is a named exit 3
hdrs=( '<!-- pair: a -> b · numbering: per-pair · prefix: PT · numbering: global -->'
       ' <!-- pair: a -> b · prefix: SW · numbering: per-pair -->'
       '<!-- prefix: PT · numbering: global.per-pair -->'
       '<!-- prefix: PT · numbering: global; numbering: per-pair -->'
       '<!-- pair: a -> b · Prefix: XY · Numbering: per-pair -->'
       '<!-- pair: a -> b · prefix: PT · numbering: globalish -->' )
hres=""
for h in "${hdrs[@]}"; do
  printf '%s\n| PT-2 | a | b | map | x | 2026-10-21 | |\n' "$h" > "$clone/$gp/w--x.md"
  bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT >/dev/null 2>"$root/eh.txt"; r=$?
  grep -q "header is not .prefix: PT · numbering: global" "$root/eh.txt" || r="x$r"
  hres="$hres $r"
done
rm -f "${clone:?}/${gp:?}/w--x.md"
check "T3: a doubled numbering, an indented foreign header, global.per-pair, a second numbering, capitalised keys and globalish are each a named exit 3 (got$hres)" '[ "$hres" = " 3 3 3 3 3 3" ]'
printf '  <!-- pair: a -> b · PREFIX: PT · Numbering: global -->\n| PT-2 | a | b | map | x | 2026-10-21 | |\n' > "$clone/$gp/w--x.md"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT >/dev/null 2>&1; rch3=$?
rm -f "${clone:?}/${gp:?}/w--x.md"
check "T3: the ruled header indented, with keys in any case, is accepted (exit 0)" '[ "$rch3" = 0 ]'
cat > "$root/diff42.txt" <<EOF
diff --git a/$gp/y--z.md b/$gp/y--z.md
new file mode 100644
--- /dev/null
+++ b/$gp/y--z.md
@@ -0,0 +1,2 @@
+<!-- pair: y -> z · prefix: SW · numbering: per-pair -->
+| PT-2 | y | z | map | x | 2026-10-21 | |
EOF
export STUB_PRS="42\tfalse\tgh42\t$gp/y--z.md\t$root/diff42.txt\n"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT >/dev/null 2>"$root/eh42.txt"; rch42=$?
check "T3: an open same-repository PR adding a pair file with a foreign header is a named exit 3, as at the tip" '[ "$rch42" = 3 ] && grep -q "header is not.*y--z.md at PR #42" "$root/eh42.txt"'
export STUB_PRS=""
g -C "$clone" switch -q main
g -C "$clone" branch -q -D haiku/kurapika/ports-same-run14
# T4: a local head whose remote is '.' is read; a refs/pull merge is skipped, by count, never by name
g -C "$clone" switch -q -c x/y/ports-dotremote
printf '| PT-95 | a | b | map | a local run tracking . | 2026-10-21 | |\n' > "$clone/$gp/dd--ee.md"
g -C "$clone" add "$gp/dd--ee.md"; g -C "$clone" commit -qm "local run"
g -C "$clone" switch -q main
g -C "$clone" config branch.x/y/ports-dotremote.remote .
g -C "$clone" config branch.x/y/ports-dotremote.merge refs/heads/main
g -C "$clone" branch -q x/y/ports-secretname main
g -C "$clone" config branch.x/y/ports-secretname.remote origin
g -C "$clone" config branch.x/y/ports-secretname.merge refs/pull/9/head
outt4="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT 2>"$root/et4.txt")"; rct4=$?
check "T4: a local head tracking '.' is read (next PT-96)" '[ "$rct4" = 0 ] && printf "%s" "$outt4" | grep -q "^next: PT-96$"'
check "T4: a refs/pull/* head is skipped by count and reason, never by name" 'grep -q "skipped 1 local ports-\* head(s) tracking refs/pull/\*" "$root/et4.txt" && ! grep -q "secretname" "$root/et4.txt" && ! printf "%s" "$outt4" | grep -q "secretname"'
g -C "$clone" branch -q -D x/y/ports-dotremote x/y/ports-secretname
# T5: JSON escapes every control character
cat > "$root/diff43.txt" <<EOF
diff --git a/$gp/a--b.md b/$gp/a--b.md
--- a/$gp/a--b.md
+++ b/$gp/a--b.md
@@ -2,0 +3,1 @@
+| PT-44 | SW-44 | KT-44 | map | control-char branch | 2026-10-21 | |
EOF
export STUB_PRS="43\tfalse\tctl\001x\t$gp/a--b.md\t$root/diff43.txt\n"
outt5="$(bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$gp/a--b.md" --prefix PT --json 2>/dev/null)"
check "T5: a control character in a branch name is escaped as \\u0001 and the JSON parses" 'printf "%s" "$outt5" | jq -e ".seen | length > 0" >/dev/null && printf "%s" "$outt5" | grep -qF "ctl\\u0001x"'
export STUB_PRS=""
# T6: --target's name is a segment: acme/. and acme/.. are usage
bash "$guard" --worktree "$clone" --target 'acme/.' --pair-file "$pair" --prefix PT >/dev/null 2>&1; rct6a=$?
bash "$guard" --worktree "$clone" --target 'acme/..' --pair-file "$pair" --prefix PT >/dev/null 2>&1; rct6b=$?
check "T6: --target acme/. and acme/.. are usage, exit 2" '[ "$rct6a" = 2 ] && [ "$rct6b" = 2 ]'
# T15: the shipped template, rendered, is a clean pair file: exit 0, its rows counted
to="$root/tmpl-origin"; tc="$root/tmpl-clone"
g init -q -b main "$to"; mkdir -p "$to/handbooks/ports"
sed 's/<from>/swiftui-tca-uzf-v2/g; s/<to>/compose-uzf-v2/g; s/<from-prefix>/SW/g; s/<to-prefix>/KT/g' "$repo_root/templates/ports/pair.md" > "$to/handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md"
sed 's/<from>/swiftui-tca-uzf-v2/g; s/<to>/compose-uzf-v2/g' "$repo_root/templates/ports/INDEX.md" > "$to/handbooks/ports/INDEX.md"
printf '| PT-3 | SW-1 | KT-1 | map | rendered | 2026-10-21 | |\n' >> "$to/handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md"
g -C "$to" add -A; g -C "$to" commit -qm tmpl; g clone -q "$to" "$tc"
outt15="$(bash "$guard" --worktree "$tc" --target acme/widget --pair-file handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md --prefix PT 2>&1)"; rct15=$?
check "T15: templates/ports/pair.md and INDEX.md rendered into the tip read clean, the row counted: exit 0, next PT-4" '[ "$rct15" = 0 ] && printf "%s" "$outt15" | grep -q "^next: PT-4$"'
export STUB_PRS="7\tfalse\ta\t$pair\t$root/diff7.txt\n"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT --base mian >/dev/null 2>"$root/eb.txt"; rct=$?
check "a tip ref that does not resolve is a named exit 2, never PT-1" '[ "$rct" = 2 ] && grep -q "origin/mian does not resolve" "$root/eb.txt"'
mv "$origin" "$origin.away"
bash "$guard" --worktree "$clone" --target acme/widget --pair-file "$pair" --prefix PT >/dev/null 2>"$root/ef.txt"; rcf=$?
mv "$origin.away" "$origin"
check "a failed fetch of origin is a named exit 2, never a stale tip" '[ "$rcf" = 2 ] && grep -q "fetching origin failed" "$root/ef.txt"'
set -e

echo "port-rule-guard: $pass/$total"
[ "$pass" = "$total" ]
