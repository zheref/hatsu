#!/usr/bin/env bash
# spec_family_fixture_check.sh — lane spec-family-guard (zheref/hatsu#405 item 4).
#
# scripts/fixtures/spec-family/ is the offline input docs/config/spec-repo.md § Fixtures names for
# nen schema check, nen repo classify / resolve, config_values.sh diagnose --domain port and nen spec
# check, plus nen run record where the nen on PATH carries it. Nothing ran them, so a fixture could
# drift from what those reads accept and nobody would notice. This lane runs every read over a copy
# (the spec repository's copy made its own repository whose origin is fixture-owner/fixture-spec, as
# the Fixtures section says the readings need), asserts each verdict, then proves each check RED on a
# drifted copy: a check that cannot fail is not a check.
#
# Offline: no read reaches GitHub (fixture-owner/* never meets gh or a networked verb,
# docs/PUBLIC-REDACTION.md). Needs bash, git, mktemp, node >= 22.18 and nen ($NEN, else nen on PATH).
# Invoked as `nen shu test --lane spec-family-guard --repo <hatsu>`; unit_tests_ci.mts runs it in CI.
# A read the nen on PATH does not carry is printed NOT CHECKED with the version, never as a pass.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$here/.." && pwd -P)"
fixtures="$root/scripts/fixtures/spec-family"
nen="${NEN:-nen}"
command -v "$nen" >/dev/null 2>&1 || { echo "spec-family-guard: no nen on PATH (NEN unset)" >&2; exit 2; }
command -v node >/dev/null 2>&1 || { echo "spec-family-guard: node is not on PATH" >&2; exit 2; }
[ -d "$fixtures/spec-repo/nen" ] || { echo "spec-family-guard: $fixtures/spec-repo/nen is missing" >&2; exit 2; }

work="$(mktemp -d "${TMPDIR:-/tmp}/spec-family-guard.XXXXXX")" || { echo "spec-family-guard: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$work"' EXIT
fails=0
pass() { echo "ok    $1"; }
fail() { echo "FAIL  $1" >&2; fails=$((fails + 1)); }

# A spec repository copy, made its own repository with the fixture origin.
copy() {
  local dest="$1"
  mkdir -p "$dest"
  cp -R "$fixtures/spec-repo/." "$dest/"
  git -C "$dest" init -q 2>/dev/null || return 1
  git -C "$dest" remote add origin https://github.com/fixture-owner/fixture-spec.git || return 1
}

# The reads, each returning 0 only when its verdict is the fixture's documented one.
read_schema() { "$nen" schema check --repo "$1" >"$work/out" 2>&1; }
read_classify() {
  "$nen" repo classify --repo "$1" >"$work/out" 2>&1 || return 1
  grep -q '^fixture-owner/fixture-spec: role spec .* gate G2$' "$work/out"
}
read_resolve() {
  "$nen" repo resolve FI --repo "$1" >"$work/out" 2>&1 || return 1
  grep -q '^fixture-owner/fixture-ios  (FI)  via code$' "$work/out"
}
read_port() { sh "$root/scripts/config_values.sh" diagnose --repo "$1" --domain port >"$work/out" 2>&1; }
read_families() {
  # HR-16: a member's families[] must equal the spec repository's copy (else missing-configuration).
  node -e '
    const fs = require("fs");
    const [a, b] = process.argv.slice(1).map((p) => JSON.stringify(JSON.parse(fs.readFileSync(p, "utf8")).families));
    process.exit(a !== undefined && a === b ? 0 : 1);
  ' "$1/nen/repos.json" "$2/nen/repos.json" >"$work/out" 2>&1
}
read_check() {
  "$nen" spec check --repo "$1" --folder specs/001-fixture-capability >"$work/out" 2>&1 || return 1
  grep -q '^folder specs/001-fixture-capability: 6 requirement line(s) -- 2 cited, 3 marked, 1 ruled, 1 stale' "$work/out" &&
    grep -q '^markers: 4 open -- 1 needs-clarification · 2 needs-ruling · 1 unverified$' "$work/out"
}
read_record() {
  XDG_STATE_HOME="$work/state" "$nen" run record write --schema hatsu.spec.run/v0.1 \
    --id dowsing-chain-fixture-family-capture-20261022 --from "$1" --dry-run >"$work/out" 2>&1 || return 1
  grep -q '^would-write: hatsu.spec.run/v0.1 dowsing-chain-fixture-family-capture-20261022 -- ' "$work/out" &&
    [ ! -e "$work/state/hatsu/specs/dowsing-chain-fixture-family-capture-20261022.json" ]
}
show() { sed 's/^/      /' "$work/out" >&2; }

copy "$work/green" || { echo "spec-family-guard: could not make the spec repository copy" >&2; exit 2; }
echo "spec-family-guard: nen $("$nen" --version 2>/dev/null) over $fixtures"

# Green: every read over the fixture as committed.
if read_schema "$work/green"; then pass "nen schema check reads the spec repository's declarations"; else fail "nen schema check"; show; fi
if read_classify "$work/green"; then pass "nen repo classify reads role spec, gate G2, from families[].spec"; else fail "nen repo classify"; show; fi
if read_resolve "$work/green"; then pass "nen repo resolve FI names fixture-owner/fixture-ios"; else fail "nen repo resolve"; show; fi
if read_port "$work/green"; then pass "config_values.sh diagnose --domain port reads every value set"; else fail "config_values.sh diagnose --domain port"; show; fi
if read_families "$work/green" "$fixtures/member"; then pass "the member's families[] equals the spec repository's"; else fail "families[] differ between the member and the spec repository"; show; fi
if read_check "$fixtures"; then pass "nen spec check counts every citation and marker form"; else fail "nen spec check"; show; fi
if "$nen" run record --help >/dev/null 2>&1; then
  if read_record "$fixtures/run-record.json"; then pass "nen run record write --dry-run validates run-record.json and writes nothing"; else fail "nen run record write --dry-run"; show; fi
else
  echo "NOT CHECKED  nen run record: nen $("$nen" --version 2>/dev/null) has no run record verb (it ships after 0.26.0)"
fi

# Red: each check must fail on a drifted copy.
red() { # <label> <command...>: the command must FAIL
  local label="$1"; shift
  if "$@"; then fail "red path not caught: $label"; else pass "red path caught: $label"; fi
}
copy "$work/red-schema" && printf '{ "families": [' >"$work/red-schema/nen/repos.json"
red "an unparseable nen/repos.json fails nen schema check" read_schema "$work/red-schema"
copy "$work/red-classify" && node -e '
  const fs = require("fs"); const p = process.argv[1]; const d = JSON.parse(fs.readFileSync(p, "utf8"));
  delete d.families[0].spec; fs.writeFileSync(p, JSON.stringify(d, null, 2));
' "$work/red-classify/nen/repos.json"
red "a family with no spec repository no longer reads role spec" read_classify "$work/red-classify"
copy "$work/red-resolve" && node -e '
  const fs = require("fs"); const p = process.argv[1]; const d = JSON.parse(fs.readFileSync(p, "utf8"));
  delete d.product_codes.FI; d.families[0].members = d.families[0].members.filter((m) => m.code !== "FI");
  fs.writeFileSync(p, JSON.stringify(d, null, 2));
' "$work/red-resolve/nen/repos.json"
red "an unregistered member code does not resolve" read_resolve "$work/red-resolve"
copy "$work/red-port" && node -e '
  const fs = require("fs"); const p = process.argv[1]; const d = JSON.parse(fs.readFileSync(p, "utf8"));
  delete d.port.specKit.pin; fs.writeFileSync(p, JSON.stringify(d, null, 2));
' "$work/red-port/nen/workflow.json"
# diagnose holds presence, not shape: an open-kind value such as port.specKit.layout is not validated
# there (a `..` layout is refused by its readers, nen spec number among them), so the red path is an
# unset value.
red "an unset port.specKit.pin reads outstanding in diagnose --domain port" read_port "$work/red-port"
mkdir -p "$work/red-member/nen" && node -e '
  const fs = require("fs"); const [from, to] = process.argv.slice(1); const d = JSON.parse(fs.readFileSync(from, "utf8"));
  d.families[0].members[0].platform = "watch"; fs.writeFileSync(to, JSON.stringify(d, null, 2));
' "$fixtures/member/nen/repos.json" "$work/red-member/nen/repos.json"
red "a member copy whose families[] differs is caught" read_families "$work/green" "$work/red-member"
mkdir -p "$work/red-check/specs" && cp -R "$fixtures/specs/." "$work/red-check/specs/" && node -e '
  const fs = require("fs"); const p = process.argv[1];
  fs.writeFileSync(p, fs.readFileSync(p, "utf8").replace(/\[NEEDS RULING\]/, ""));
' "$work/red-check/specs/001-fixture-capability/spec.md"
red "a marker dropped from the spec folder changes nen spec check's counts" read_check "$work/red-check"
if "$nen" run record --help >/dev/null 2>&1; then
  node -e '
    const fs = require("fs"); const [from, to] = process.argv.slice(1); const d = JSON.parse(fs.readFileSync(from, "utf8"));
    d.next = "finished"; fs.writeFileSync(to, JSON.stringify(d, null, 2));
  ' "$fixtures/run-record.json" "$work/red-record.json"
  red "a record whose next is outside the closed set is refused" read_record "$work/red-record.json"
fi

if [ "$fails" -ne 0 ]; then
  echo "spec-family-guard: $fails check(s) failed" >&2
  exit 1
fi
echo "spec-family-guard: every read holds over scripts/fixtures/spec-family/, and every red path is caught"
