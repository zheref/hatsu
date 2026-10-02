#!/usr/bin/env bash
# hanten_cycle_ledger_fixture.sh -- the ledger-guard lane's one entry. QA-18
# negative tests for the
# 0.67.0 late-persona hydration in scripts/hanten_cycle_ledger.sh.
#
# TEST-ONLY. Nothing installed reads this file; it is not a plugin surface.
#
# The loader's own contract (its LATE_PERSONAS comment): an ABSENT leorio row
# is hydrated at used 0 because "he could not have run" in a ledger opened
# before 0.67.0 -- and "counts are never minted for someone who could have
# run". A ledger OPENED BY 0.67.0 is one where he could have run. Losing his
# row there must refuse exactly as a lost feitan row does, or the budget the
# ledger exists to hold is re-minted by deleting (or re-casing) one key.
#
# The self-test proves the old-ledger case, a malformed row and a missing
# non-late row; this fixture drives the ledgers that already knew him (opened
# after he existed, or hydrated once) and holds the fix (personasAtOpen,
# lateHydrated) to refusing a lost row there.
#
# It also holds `ensure` (zheref/hatsu#169), the open for a branch breath did
# not cut, on real git checkouts: app-created (opened, stamped, then present),
# breath-created (present, byte-identical), the trunk and a detached HEAD
# (refused, nothing written), every lost-ledger signal (exit 3), what is NOT
# evidence (a pushed remote ref, a rename of a fresh branch), every other
# refusal (exit 2), and Phinks' adversarial cases from hanten on d09b7132.
#
#   bash scripts/hanten_cycle_ledger_fixture.sh   (lane: ledger-guard)
#
# Exit 0 when every case holds; exit 1 naming each that did not.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEDGER="$HERE/hanten_cycle_ledger.sh"
[ -f "$LEDGER" ] || { echo "no ledger script at $LEDGER" >&2; exit 2; }

# The script's own embedded self-test first: this fixture is the ledger-guard
# lane's one entry, so the lane runs both.
bash "$LEDGER" --self-test >/dev/null 2>&1 || { echo "hanten_cycle_ledger.sh --self-test failed; run it alone to see which case" >&2; exit 1; }
echo "ok    hanten_cycle_ledger.sh --self-test"

root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu ledger late.XXXXXX")"   # a path with a space
trap 'rm -rf "$root"' EXIT
fails=0
fail() { printf 'FAIL  %s\n' "$*" >&2; fails=$((fails + 1)); }
pass() { printf 'ok    %s\n' "$*"; }

edit() {  # edit <ledger file> <python expression over d["reviewers"] as r>
  python3 - "$1" "$2" <<'PY'
import json, sys
p, expr = sys.argv[1], sys.argv[2]
d = json.load(open(p)); r = d["reviewers"]
exec(expr)
open(p, "w").write(json.dumps(d, indent=2) + "\n")
PY
}

open_spent() {  # a ledger OPENED BY THE CANDIDATE in which leorio already ran 1/1
  local repo="$1" branch="$2"
  mkdir -p "$repo"
  bash "$LEDGER" init   --repo "$repo" --branch "$branch" >/dev/null || return 1
  bash "$LEDGER" record --repo "$repo" --branch "$branch" --persona leorio --outcome ran >/dev/null || return 1
}

# Case 1 -- the leorio row of a post-0.67.0 ledger deleted: must refuse (exit 2).
repo="$root/deleted"; branch="topic/deleted"
open_spent "$repo" "$branch" || { echo "setup failed" >&2; exit 2; }
edit "$repo/.nen/hanten/topic-deleted.cycle.json" 'del r["leorio"]'
out="$(bash "$LEDGER" decide --repo "$repo" --branch "$branch" --applicable leorio 2>&1)"; code=$?
if [ "$code" -eq 2 ]; then pass "deleted leorio row in a 0.67.0-opened ledger refuses"
else fail "deleted leorio row in a 0.67.0-opened ledger: exit $code, raise=$(printf '%s' "$out" | python3 -c 'import json,sys
try: print(json.load(sys.stdin)["raise"])
except Exception: print("?")') (leorio ran 1/1 before the row was lost)"; fi

# Case 2 -- the same row re-cased ("Leorio"): the spent row survives beside a minted one.
repo="$root/recased"; branch="topic/recased"
open_spent "$repo" "$branch" || { echo "setup failed" >&2; exit 2; }
edit "$repo/.nen/hanten/topic-recased.cycle.json" 'r["Leorio"] = r.pop("leorio")'
out="$(bash "$LEDGER" decide --repo "$repo" --branch "$branch" --applicable leorio 2>&1)"; code=$?
if [ "$code" -eq 2 ]; then pass "re-cased leorio row in a 0.67.0-opened ledger refuses"
else fail "re-cased leorio row in a 0.67.0-opened ledger: exit $code (leorio ran 1/1 under key 'Leorio')"; fi

# Control -- the non-late persona in the same situation already refuses.
repo="$root/feitan"; branch="topic/feitan"
open_spent "$repo" "$branch" || { echo "setup failed" >&2; exit 2; }
edit "$repo/.nen/hanten/topic-feitan.cycle.json" 'del r["feitan"]'
bash "$LEDGER" decide --repo "$repo" --branch "$branch" --applicable feitan >/dev/null 2>&1; code=$?
if [ "$code" -eq 2 ]; then pass "control: deleted feitan row refuses"; else fail "control: deleted feitan row exit $code"; fi

# Control -- a ledger in the exact 0.66.0 shape (six rows, written by that
# release, nothing else on it) still loads with leorio hydrated. A fix must
# keep this green: the leniency is right for ledgers that predate him.
repo="$root/pre-0.67"; branch="topic/pre"
mkdir -p "$repo/.nen/hanten"
python3 - "$repo/.nen/hanten/topic-pre.cycle.json" <<'PY'
import json, sys
rows = {p: {"max": m, "used": 0, "budgetSource": "default", "invocations": []}
        for p, m in (("nobunaga", 2), ("feitan", 1), ("chrollo", 1), ("phinks", 1), ("hisoka", 2), ("uvogin", 3))}
json.dump({"contract": "hatsu.hanten.cycle/v0.1", "branch": "topic/pre", "pr": None, "slug": "topic-pre",
           "openedAt": "2026-09-29T00:00:00.000Z", "updatedAt": "2026-09-29T00:00:00.000Z",
           "reviewers": rows}, open(sys.argv[1], "w"), indent=2)
PY
out="$(bash "$LEDGER" decide --repo "$repo" --branch "$branch" --applicable leorio 2>&1)"; code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '"raise": \[' && printf '%s' "$out" | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["raise"]==["leorio"] else 1)'; then
  pass "control: a 0.66.0-shaped ledger loads with leorio hydrated"
else fail "control: 0.66.0-shaped ledger exit $code"; fi

# Case 3 -- a 0.66.0-shaped ledger that hydrated leorio and recorded his run,
# then lost the row: the hydration is on record (lateHydrated), so it refuses.
bash "$LEDGER" record --repo "$repo" --branch "$branch" --persona leorio --outcome ran >/dev/null 2>&1
edit "$repo/.nen/hanten/topic-pre.cycle.json" 'del r["leorio"]'
bash "$LEDGER" decide --repo "$repo" --branch "$branch" --applicable leorio >/dev/null 2>&1; code=$?
if [ "$code" -eq 2 ]; then pass "a hydrated-then-deleted leorio row in a pre-0.67 ledger refuses"
else fail "hydrated-then-deleted leorio row in a pre-0.67 ledger: exit $code"; fi

# --- ensure (zheref/hatsu#169) ----------------------------------------------
# Real git checkouts (ensure refuses anything else), a hermetic identity, and a
# fake `gh` on PATH so the PR check is offline: FAKE_GH_PRS is its JSON answer,
# FAKE_GH_FAIL=1 makes it fail. Phinks' adversarial cases (hanten on d09b7132,
# R1-R8, C1-C4) are folded in; C1/C2 run on git checkouts here.
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir -p "$root/bin"
cat > "$root/bin/gh" <<'GH'
#!/bin/sh
[ "${FAKE_GH_FAIL:-0}" = 1 ] && { echo "gh: not authenticated" >&2; exit 4; }
printf '%s\n' "${FAKE_GH_PRS:-[]}"
GH
chmod +x "$root/bin/gh"
PATH="$root/bin:$PATH"; export PATH
ens() { bash "$LEDGER" ensure "$@" 2>/dev/null; }
field() { printf '%s' "$1" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get(sys.argv[1], "?"))
except Exception: print("?")' "$2"; }
sum_of() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }
no_ledger() { [ -z "$(find "$1" -name '*.cycle.json' 2>/dev/null)" ]; }
mkrepo() {  # mkrepo <dir> <branch>: a git checkout on <branch>
  git init -q -b main "$1" && git -C "$1" commit -q --allow-empty -m init \
    && { [ "$2" = main ] || git -C "$1" switch -q -c "$2"; } || { echo "setup failed: $1" >&2; exit 2; }
}
expect() {  # expect <label> <want exit> <want action|reason> <got exit> <json>
  local got_a; got_a="$(field "$5" action)"; [ "$got_a" = refused ] && got_a="$(field "$5" reason)"
  if [ "$4" -eq "$2" ] && [ "$got_a" = "$3" ]; then pass "ensure: $1"; else fail "ensure: $1: exit $4 ($got_a), want $2 ($3)"; fi
}

# 1. App-created branch: opened through init, stamped; a second ensure is present, unchanged.
r="$root/e-app"; mkrepo "$r" opus/k/app; f="$r/.nen/hanten/opus-k-app.cycle.json"
out="$(ens --repo "$r" --branch opus/k/app)"; expect "app-created branch is opened" 0 opened $? "$out"
stamp="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("openedAs"), bool(d["evidenceSearched"]["checkouts"]), d["evidenceSearched"]["prCheck"].startswith("gh"))' "$f" 2>/dev/null)"
[ "$stamp" = "ensure True True" ] && pass "ensure: the opened ledger is stamped openedAs ensure with what was searched" || fail "ensure: stamp: $stamp"
bash "$LEDGER" decide --repo "$r" --branch opus/k/app --applicable chrollo >/dev/null 2>&1 && pass "ensure: decide reads the opened ledger" || fail "ensure: decide on opened ledger"
before="$(sum_of "$f")"; out="$(ens --repo "$r" --branch opus/k/app)"; code=$?
expect "a second ensure is present" 0 present $code "$out"
[ "$(sum_of "$f")" = "$before" ] && pass "ensure: ... and the file is byte-identical" || fail "ensure: second ensure changed the file"

# 2. Breath-created branch with a spent review: present, untouched.
r="$root/e-breath"; mkrepo "$r" opus/k/breath; f="$r/.nen/hanten/opus-k-breath.cycle.json"
bash "$LEDGER" init --repo "$r" --branch opus/k/breath >/dev/null 2>&1 && bash "$LEDGER" record --repo "$r" --branch opus/k/breath --persona chrollo --outcome ran >/dev/null 2>&1 || { echo "setup failed" >&2; exit 2; }
before="$(sum_of "$f")"; out="$(ens --repo "$r" --branch opus/k/breath)"; code=$?
expect "breath-created branch is present" 0 present $code "$out"
[ "$(sum_of "$f")" = "$before" ] && pass "ensure: ... untouched, chrollo stays 1/1" || fail "ensure: breath ledger changed"

# 3. Trunk and detached HEAD: refused before any lock, nothing written (R4, R6, C4).
r="$root/e-trunk"; mkrepo "$r" main
out="$(ens --repo "$r" --branch main)"; expect "trunk main refused" 2 trunk $? "$out"
[ ! -e "$r/.nen" ] && pass "ensure: the trunk refusal wrote nothing, not even a lock" || fail "ensure: trunk refusal wrote $(find "$r/.nen" -type f)"
out="$(ens --repo "$r" --branch main --base develop)"; expect "--base adds to the trunk set, main still refused (R4)" 2 trunk $? "$out"
out="$(ens --repo "$r" --branch develop --base origin/develop)"; expect "--base origin/develop refuses develop" 2 trunk $? "$out"
mkdir -p "$r/nen"; printf '{"branch": {"base": "origin/trunk"}}\n' > "$r/nen/workflow.json"
out="$(ens --repo "$r" --branch trunk)"; expect "declared branch.base (origin/ stripped) refused" 2 trunk $? "$out"
for b in "" HEAD; do out="$(ens --repo "$r" --branch "$b")"; expect "detached head '$b' refused" 2 detached-head $? "$out"; done
r="$root/e-detached"; mkrepo "$r" opus/k/d; git -C "$r" switch -q --detach
out="$(ens --repo "$r" --branch opus/k/d)"; expect "a checkout in detached HEAD refused" 2 detached-head $? "$out"
no_ledger "$root/e-trunk" && no_ledger "$r" && pass "ensure: no trunk or detached ledger opened" || fail "ensure: a trunk/detached ledger exists"
# origin/<base>'s declaration counts even when the working tree drops it.
r="$root/e-origin"; mkrepo "$r" main; mkdir -p "$r/nen"; printf '{"branch": {"base": "release"}}\n' > "$r/nen/workflow.json"
git -C "$r" add nen && git -C "$r" commit -q -m decl && git -C "$r" update-ref refs/remotes/origin/main HEAD \
  && git -C "$r" switch -q -c release && rm "$r/nen/workflow.json" || { echo "setup failed" >&2; exit 2; }
out="$(ens --repo "$r" --branch release)"; expect "origin/main's declared base refused though the working tree deleted it" 2 trunk $? "$out"

# 4. Lost ledger: review evidence, no ledger here -> exit 3, nothing opened.
lost() {  # lost <label> <repo> <branch>
  out="$(ens --repo "$2" --branch "$3")"; code=$?
  expect "$1" 3 lost-ledger $code "$out"
  [ ! -f "$2/.nen/hanten/$(printf '%s' "$3" | tr / -).cycle.json" ] || fail "ensure: $1 opened a ledger"
}
r="$root/e-lost-pr"; mkrepo "$r" opus/k/lost; bash "$LEDGER" init --repo "$r" --branch opus/k/lost --pr 9 >/dev/null 2>&1
lost "a PR-keyed ledger is evidence" "$r" opus/k/lost
r="$root/e-lost-find"; mkrepo "$r" opus/k/lost; mkdir -p "$r/Reports/hanten"; printf '{}\n' > "$r/Reports/hanten/opus-k-lost.json"
lost "a findings record under Reports is evidence" "$r" opus/k/lost
r="$root/e-lost-decl"; mkrepo "$r" opus/k/lost; mkdir -p "$r/nen" "$r/Rep/hanten"; printf '{"reports": {"dir": "Rep"}}\n' > "$r/nen/workflow.json"; printf '{}\n' > "$r/Rep/hanten/opus-k-lost.json"
lost "a findings record under the declared reports.dir is evidence" "$r" opus/k/lost
r="$root/e-lost-lock"; mkrepo "$r" opus/k/lost; bash "$LEDGER" init --repo "$r" --branch opus/k/lost >/dev/null 2>&1; rm "$r/.nen/hanten/opus-k-lost.cycle.json"
lost "a leftover lock with its ledger deleted is evidence" "$r" opus/k/lost
m="$root/e-lost-wt/main"; wt="$root/e-lost-wt/wt"; mkrepo "$m" feat/x
bash "$LEDGER" init --repo "$m" --branch feat/x >/dev/null 2>&1 && bash "$LEDGER" record --repo "$m" --branch feat/x --persona phinks --outcome ran >/dev/null 2>&1
git -C "$m" switch -q main && git -C "$m" worktree add -q "$wt" feat/x || { echo "setup failed" >&2; exit 2; }
lost "another worktree's spent ledger is evidence (R1)" "$wt" feat/x
r="$root/e-lost-rename"; mkrepo "$r" claude/happy-x; bash "$LEDGER" init --repo "$r" --branch claude/happy-x >/dev/null 2>&1
git -C "$r" branch -m claude/happy-x opus/k/real-name
lost "a ledger under the pre-rename name (reflog) is evidence (R3)" "$r" opus/k/real-name
r="$root/e-lost-gh"; mkrepo "$r" opus/k/pr
out="$(FAKE_GH_PRS='[{"number": 12, "headRefName": "opus/k/pr"}]' ens --repo "$r" --branch opus/k/pr)"; expect "a PR whose head is the branch is evidence" 3 lost-ledger $? "$out"
nfc="$(printf 'feat/caf\303\251')"; nfd="$(printf 'feat/cafe\314\201')"
r="$root/e-lost-nfd"; mkrepo "$r" "$nfd"; bash "$LEDGER" init --repo "$r" --branch "$nfc" --pr 4 >/dev/null 2>&1
out="$(ens --repo "$r" --branch "$nfd")"; expect "an NFD caller sees the NFC PR-keyed ledger (R8b)" 3 lost-ledger $? "$out"

# 5. Not evidence: a rename of a never-reviewed branch, a pushed remote ref, a
# branch named <x>-pr<N>'s own ledger; and --no-pr-check (stamped).
r="$root/e-rename-new"; mkrepo "$r" claude/fresh; git -C "$r" branch -m claude/fresh opus/k/fresh
out="$(ens --repo "$r" --branch opus/k/fresh)"; expect "a renamed never-reviewed branch is a new effort" 0 opened $? "$out"
r="$root/e-pushed"; mkrepo "$r" opus/k/pushed; git init -q --bare "$root/e-pushed.git"
git -C "$r" remote add origin "$root/e-pushed.git" && git -C "$r" push -q -u origin opus/k/pushed 2>/dev/null
out="$(ens --repo "$r" --branch opus/k/pushed)"; expect "a pushed branch (remote ref alone) is opened" 0 opened $? "$out"
r="$root/e-xpr"; mkrepo "$r" x
bash "$LEDGER" init --repo "$r" --branch x-pr3 >/dev/null 2>&1
out="$(ens --repo "$r" --branch x)"; expect "branch x-pr3's own ledger is not x's evidence" 0 opened $? "$out"
r="$root/e-nogh"; mkrepo "$r" opus/k/nogh
out="$(FAKE_GH_FAIL=1 ens --repo "$r" --branch opus/k/nogh)"; expect "a failing PR check refuses" 2 refused $? "$out"
no_ledger "$r" && pass "ensure: ... and opens nothing" || fail "ensure: failing PR check opened a ledger"
out="$(FAKE_GH_FAIL=1 ens --repo "$r" --branch opus/k/nogh --no-pr-check)"; expect "--no-pr-check opens" 0 opened $? "$out"
grep -q '"prCheck": "skipped' "$r/.nen/hanten/opus-k-nogh.cycle.json" && pass "ensure: ... and the skip is stamped" || fail "ensure: --no-pr-check not stamped"

# 6. Every other refusal is exit 2 `refused`, nothing opened.
r="$root/e-ref"; mkrepo "$r" opus/k/ref; mkdir -p "$r/sub"
out="$(cd "$r/sub" && ens --repo . --branch opus/k/ref)"; expect "a subdirectory --repo (R2)" 2 refused $? "$out"
out="$(ens --repo "$r" --branch opus/k/other)"; expect "--branch not the checked-out branch" 2 refused $? "$out"
out="$(ens --repo "$r" --branch 'opus/k/ref ')"; expect "an invalid branch name (R8a)" 2 refused $? "$out"
out="$(ens --repo "$r" --branch opus/k/ref --pr 3)"; expect "--pr" 2 refused $? "$out"
out="$(ens --repo "$r" --branch opus/k/ref --confirmed-first-cycle)"; expect "--confirmed-first-cycle" 2 refused $? "$out"
out="$(ens --repo "$root" --branch opus/k/ref)"; expect "a directory that is not a git checkout" 2 refused $? "$out"
mkdir -p "$r/nen"
for kind in truncated non-utf8 base-not-string reports-absolute reports-climbs; do
  case "$kind" in
    truncated) printf '{"branch": {"base": "develop"}' ;;
    non-utf8) printf '{"branch": {"base": "develop"}, "x": "\377"}\n' ;;
    base-not-string) printf '{"branch": {"base": ["develop"]}}\n' ;;
    reports-absolute) printf '{"reports": {"dir": "/tmp/elsewhere"}}\n' ;;
    reports-climbs) printf '{"reports": {"dir": "../x"}}\n' ;;
  esac > "$r/nen/workflow.json"
  out="$(ens --repo "$r" --branch opus/k/ref)"; expect "workflow.json $kind fails closed (R5)" 2 refused $? "$out"
done
rm -rf "$r/nen"
mkdir -p "$r/.nen/hanten"; printf 'x\n' > "$r/.nen/hanten/keep"; git -C "$r" add -f .nen/hanten/keep
out="$(ens --repo "$r" --branch opus/k/ref)"; expect "a tracked .nen/hanten" 2 refused $? "$out"
git -C "$r" rm -q --cached .nen/hanten/keep; rm -rf "$r/.nen"; mkdir -p "$root/elsewhere" "$r/.nen"; ln -s "$root/elsewhere" "$r/.nen/hanten"
out="$(ens --repo "$r" --branch opus/k/ref)"; expect "a symlinked .nen/hanten" 2 refused $? "$out"
no_ledger "$r" && no_ledger "$root/elsewhere" && pass "ensure: no refusal opened a ledger" || fail "ensure: a refusal opened a ledger"
r="$root/e-r7"; mkrepo "$r" a/b; bash "$LEDGER" init --repo "$r" --branch a-b >/dev/null 2>&1
out="$(ens --repo "$r" --branch a/b)"; expect "a slug collision a/b vs a-b is not present (R7a)" 2 refused $? "$out"
r="$root/e-r7b"; mkrepo "$r" opus/k/c; mkdir -p "$r/.nen/hanten"; printf 'not json' > "$r/.nen/hanten/opus-k-c.cycle.json"
out="$(ens --repo "$r" --branch opus/k/c)"; expect "a corrupt ledger is not present (R7b)" 2 refused $? "$out"

# 7. Controls: 20 concurrent ensures open once (C1); cwd=/ with a spaced absolute --repo (C2).
r="$root/e-race"; mkrepo "$r" opus/k/race
for i in $(seq 1 20); do (ens --repo "$r" --branch opus/k/race > "$root/race.$i"; echo $? >> "$root/race.rc") & done; wait
opened="$(cat "$root"/race.[0-9]* | grep -c '"action": "opened"')"; nonzero="$(grep -vc '^0$' "$root/race.rc")"
[ "$opened" -eq 1 ] && [ "$nonzero" -eq 0 ] && pass "ensure: 20 concurrent ensures: 1 opened, 19 present, all exit 0 (C1)" || fail "ensure: concurrent: opened $opened, non-zero $nonzero"
r="$root/e c2 space"; mkrepo "$r" opus/k/cwd
out="$(cd / && ens --repo "$r" --branch opus/k/cwd)"; expect "cwd=/ with a spaced absolute --repo opens there (C2)" 0 opened $? "$out"

[ "$fails" -eq 0 ] || { echo "hanten_cycle_ledger_fixture: $fails case(s) did not hold" >&2; exit 1; }
echo "hanten_cycle_ledger_fixture: all cases hold"
