#!/usr/bin/env bash
# hanten_cycle_ledger_late_persona_fixture.sh -- QA-18 negative tests for the
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
# not cut: an app-created branch (no ledger, then opened, a second ensure
# untouched), a breath-created branch (present, byte for byte untouched), the
# trunk and a detached HEAD (refused, none opened), and a lost ledger (review
# evidence, no branch ledger: refused, never a fresh budget).
#
#   bash scripts/hanten_cycle_ledger_late_persona_fixture.sh   (lane: ledger-guard)
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
ens() { bash "$LEDGER" ensure "$@" 2>&1; }
action_of() { printf '%s' "$1" | python3 -c 'import json,sys
try: print(json.load(sys.stdin)["action"])
except Exception: print("?")'; }
sum_of() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

# Case 4 -- an app-created branch: no ledger, ensure opens it through init; a
# second ensure (a resumed session) reports present and changes nothing.
repo="$root/app"; branch="opus/kurapika/app-cut"; f="$repo/.nen/hanten/opus-kurapika-app-cut.cycle.json"
mkdir -p "$repo"
out="$(ens --repo "$repo" --branch "$branch")"; code=$?
if [ "$code" -eq 0 ] && [ "$(action_of "$out")" = opened ] && [ -f "$f" ] \
   && bash "$LEDGER" decide --repo "$repo" --branch "$branch" --applicable chrollo >/dev/null 2>&1; then
  pass "ensure: app-created branch with no ledger is opened, and decide reads it"
else fail "ensure: app-created branch: exit $code, $out"; fi
before="$(sum_of "$f")"
out="$(ens --repo "$repo" --branch "$branch")"; code=$?
if [ "$code" -eq 0 ] && [ "$(action_of "$out")" = present ] && [ "$(sum_of "$f")" = "$before" ]; then
  pass "ensure: a second ensure on the app-created branch reports present, file unchanged"
else fail "ensure: second ensure: exit $code, $out"; fi

# Case 5 -- a breath-created branch: breath's init, a review recorded; ensure
# must report present and leave every byte (and the spent count) alone.
repo="$root/breath"; branch="opus/kurapika/breath-cut"; f="$repo/.nen/hanten/opus-kurapika-breath-cut.cycle.json"
mkdir -p "$repo"
bash "$LEDGER" init --repo "$repo" --branch "$branch" >/dev/null 2>&1 \
  && bash "$LEDGER" record --repo "$repo" --branch "$branch" --persona chrollo --outcome ran >/dev/null 2>&1 \
  || { echo "setup failed" >&2; exit 2; }
before="$(sum_of "$f")"
out="$(ens --repo "$repo" --branch "$branch")"; code=$?
if [ "$code" -eq 0 ] && [ "$(action_of "$out")" = present ] && [ "$(sum_of "$f")" = "$before" ]; then
  pass "ensure: breath-created branch is present and untouched (chrollo stays 1/1)"
else fail "ensure: breath-created branch: exit $code, $out"; fi

# Case 6 -- the trunk gets no ledger: main by default, the declared
# branch.base when nen/workflow.json names one, --base when given, and a
# detached HEAD. Each refuses at exit 2 and writes nothing.
repo="$root/trunk"; mkdir -p "$repo"
for args in "--branch main" "--branch HEAD" "--branch develop --base develop"; do
  # shellcheck disable=SC2086
  out="$(ens --repo "$repo" $args)"; code=$?
  if [ "$code" -eq 2 ] && [ -z "$(ls -A "$repo/.nen/hanten" 2>/dev/null | grep cycle.json)" ]; then
    pass "ensure: refused on $args, none opened"
  else fail "ensure: $args: exit $code, $out"; fi
done
mkdir -p "$repo/nen"; printf '{"branch": {"base": "trunk"}}\n' > "$repo/nen/workflow.json"
out="$(ens --repo "$repo" --branch trunk)"; code=$?
if [ "$code" -eq 2 ] && [ ! -f "$repo/.nen/hanten/trunk.cycle.json" ]; then
  pass "ensure: the declared branch.base is the trunk, refused, none opened"
else fail "ensure: declared branch.base: exit $code, $out"; fi

# Case 7 -- a lost ledger: review evidence for the branch (a PR-keyed ledger,
# or hanten's findings record) with no branch ledger refuses, writes nothing.
repo="$root/lost-pr"; branch="opus/kurapika/lost"; mkdir -p "$repo"
bash "$LEDGER" init --repo "$repo" --branch "$branch" --pr 9 >/dev/null 2>&1 || { echo "setup failed" >&2; exit 2; }
out="$(ens --repo "$repo" --branch "$branch")"; code=$?
if [ "$code" -eq 2 ] && [ ! -f "$repo/.nen/hanten/opus-kurapika-lost.cycle.json" ]; then
  pass "ensure: a PR-keyed ledger with no branch ledger is a lost ledger, refused"
else fail "ensure: PR-keyed evidence: exit $code, $out"; fi
repo="$root/lost-findings"; mkdir -p "$repo/Reports/hanten"; printf '{}\n' > "$repo/Reports/hanten/opus-kurapika-lost.json"
out="$(ens --repo "$repo" --branch "$branch")"; code=$?
if [ "$code" -eq 2 ] && [ ! -f "$repo/.nen/hanten/opus-kurapika-lost.cycle.json" ]; then
  pass "ensure: a hanten findings record with no branch ledger is a lost ledger, refused"
else fail "ensure: findings evidence: exit $code, $out"; fi
out="$(ens --repo "$root/app" --branch "opus/kurapika/app-cut" --pr 3)"; code=$?
if [ "$code" -eq 2 ]; then pass "ensure: --pr refused (the PR-keyed ledger is hanten § 2b's init --pr)"
else fail "ensure: --pr: exit $code, $out"; fi

[ "$fails" -eq 0 ] || { echo "hanten_cycle_ledger_late_persona_fixture: $fails case(s) did not hold" >&2; exit 1; }
echo "hanten_cycle_ledger_late_persona_fixture: all cases hold"
