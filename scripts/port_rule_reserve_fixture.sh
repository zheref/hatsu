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
<!-- pair: swiftui-tca-uzf-v2 -> compose-uzf-v2 · prefix: PT -->
| id | source | target | handling | rationale | date | supersedes |
|---|---|---|---|---|---|---|
| PT-1 | SW-3 | KT-2 | mirror | same shape | 2026-10-20 | |
| PT-2 | TCA Effect.run | Hilt repository call | map | effects become injected calls | 2026-10-20 | |
| PT-3 | SwiftUI .sheet | ModalBottomSheet | map | the idiom | 2026-10-20 | |
MD
printf '| PT-1 | a | b | mirror | x | 2026-10-20 | |\n' > "$origin/p/x.md"
printf 'q\n' > "$origin/q.md"
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
+<!-- pair: swiftui-tca-uzf-v2 -> compose-uzf-v2 · prefix: PT (typo fixed) -->
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

# the gh stub. STUB_PRS: lines "num<TAB>fork<TAB>ref<TAB>files(comma)<TAB>diff-file"; STUB_TOTAL overrides
# the search total; STUB_CHANGED overrides changedFiles for PR 7 (a short file list)
stub="$root/bin"; mkdir -p "$stub"
cat > "$stub/gh" <<'SH'
#!/usr/bin/env bash
prs() { printf '%b' "${STUB_PRS:-}"; }
case "$1 $2" in
  "api search/issues"*) if [ -n "${STUB_TOTAL:-}" ]; then echo "$STUB_TOTAL"; else prs | grep -c . || true; fi ;;
  "pr list") prs | awk -F'\t' -v ch="${STUB_CHANGED:-}" '{ n=split($4, a, ","); if (ch != "" && $1 == 7) n=ch; printf "%s\t%s\t%s\t%s\n", $1, $2, n, $3 }' ;;
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
check "--check: an id this branch adds that a sibling branch carries is exit 3, naming both" '[ "$rcck" = 3 ] && grep -q "PT-4 also at branch origin/fable/kurapika/ports-swiftui-tca-uzf-v2--compose-uzf-v2-run1" "$root/ec.txt"'
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
check "a pair file absent at the tip and in every PR reserves PT-1 (exit $rcn)" '[ "$rcn" = 0 ] && printf "%s" "$outn" | grep -q "^next: PT-1$"'

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
check "a PR naming the pair file with no hunk header (a rename) is exit 1, named, never read as empty" '[ "$rc15" = 1 ] && grep -q "PR #15 names the pair file but its diff carries no hunk header" "$root/e15.txt"'
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
check "a fork PR at the ceiling or out of shape is listed as not counted and never moves the id (exit $rcf2)" '[ "$rcf2" = 0 ] && printf "%s" "$outf" | grep -q "^next: PT-5$" && printf "%s" "$outf" | grep -q "PT-999999999 PR #14 (forkmax) fork, not counted" && printf "%s" "$outf" | grep -q "PT-010 PR #9 (forkbad) fork, not counted"'
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
