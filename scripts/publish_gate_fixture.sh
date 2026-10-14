#!/usr/bin/env bash
# publish_gate_fixture.sh — proves scripts/publish_gate.sh refuses the push at every gate (zheref/hatsu#218).
#
# Lane `publish-gate-guard`: `nen shu test --lane publish-gate-guard --repo <hatsu>`. The nen half is
# stubbed: a `nen` shim on PATH answers `wc catch-up`, `shu lint` and `wc publish` from environment
# variables (NEN_STUB_NOOP, NEN_STUB_LINT, NEN_STUB_PUBLISH), so the fixture is hermetic and offline and
# proves the SCRIPT's chain, never nen. Real git is used for the repository, its remote and the
# authorship check (scripts/branch_authorship_check.sh, with the Hatsu-Agent trailer). Each case names
# its own failure.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
guard="$here/publish_gate.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
passed=0; failed=0

# the nen shim
mkdir -p "$tmp/bin"
cat > "$tmp/bin/nen" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "wc catch-up") printf '{ "noOp": %s }\n' "${NEN_STUB_NOOP:-true}"; exit "${NEN_STUB_CATCHUP_EXIT:-0}" ;;
  "shu lint"|"shu build"|"shu test") echo "stub $2 ran"; exit "${NEN_STUB_LINT:-0}" ;;
  "wc publish") echo "stub published"; exit "${NEN_STUB_PUBLISH:-0}" ;;
  *) echo "stub: unknown $*" >&2; exit 9 ;;
esac
EOF
chmod +x "$tmp/bin/nen"
export PATH="$tmp/bin:$PATH"
unset NEN

# a remote, a published branch with one outgoing commit carrying the trailer
remote="$tmp/remote.git"; repo="$tmp/repo"
git init -q --bare "$remote"
git init -q "$repo"; git -C "$repo" config user.email f@x; git -C "$repo" config user.name fixture; git -C "$repo" config commit.gpgsign false
echo a > "$repo/a"; git -C "$repo" add a; git -C "$repo" commit -q -m "chore: base"
git -C "$repo" branch -M main; git -C "$repo" remote add origin "$remote"; git -C "$repo" push -q -u origin main
git -C "$repo" switch -q -c fable/kurapika/effort; git -C "$repo" push -q -u origin fable/kurapika/effort
echo b > "$repo/b"; git -C "$repo" add b; git -C "$repo" commit -q -m "$(printf 'feat: outgoing\n\nbody\n\nHatsu-Agent: kurapika')"
proved="$(git -C "$repo" rev-parse HEAD)"
run() { # $1 case, $2 expected exit, $3 needle, then env assignments as the remaining args
  name="$1"; want="$2"; needle="$3"; shift 3
  out="$(env "$@" bash "$guard" --repo "$repo" --base main --proved "$proved" --check lint --lane plugin --persona kurapika --dry-run 2>&1)"; code=$?
  if [ "$code" = "$want" ] && printf '%s' "$out" | grep -qF -- "$needle"; then passed=$((passed+1)); echo "ok    $name"
  else failed=$((failed+1)); echo "FAIL  $name: expected exit $want carrying '$needle', got exit $code"; printf '%s\n' "$out" | sed 's/^/      /'; fi
}

run "every gate yes: would publish" 0 "would publish" NEN_STUB_NOOP=true
run "gate 1: catch-up exit 1 refuses" 1 "gate 1" NEN_STUB_CATCHUP_EXIT=1
run "gate 1: noOp false refuses" 1 "noOp is not true" NEN_STUB_NOOP=false
run "gate 4: a red iteration check refuses" 1 "gate 4" NEN_STUB_LINT=1
# gate 2: a moved HEAD
git -C "$repo" commit -q --allow-empty -m "$(printf 'chore: moved\n\nHatsu-Agent: kurapika')"
run "gate 2: HEAD past the proved SHA refuses" 1 "gate 2" NEN_STUB_NOOP=true
git -C "$repo" reset -q --hard "$proved"
# gate 5: a commit without the trailer
echo c > "$repo/c"; git -C "$repo" add c; git -C "$repo" commit -q -m "feat: no trailer"
bad="$(git -C "$repo" rev-parse HEAD)"
out="$(bash "$guard" --repo "$repo" --base main --proved "$bad" --check lint --lane plugin --persona kurapika --dry-run 2>&1)"; code=$?
if [ "$code" = 1 ] && printf '%s' "$out" | grep -qF "gate 5"; then passed=$((passed+1)); echo "ok    gate 5: a commit without the trailer refuses"; else failed=$((failed+1)); echo "FAIL  gate 5: expected exit 1 carrying 'gate 5', got $code"; printf '%s\n' "$out" | sed 's/^/      /'; fi
git -C "$repo" reset -q --hard "$proved"
# gate 3: no upstream
git -C "$repo" branch --unset-upstream
run "gate 3: no upstream refuses" 1 "gate 3" NEN_STUB_NOOP=true
git -C "$repo" branch -u origin/fable/kurapika/effort
# wiring
out="$(bash "$guard" --repo "$repo" --base main 2>&1)"; code=$?
if [ "$code" = 2 ]; then passed=$((passed+1)); echo "ok    wiring: a missing argument is exit 2"; else failed=$((failed+1)); echo "FAIL  wiring: expected exit 2, got $code"; fi
# the real push, stubbed publish
out="$(NEN_STUB_NOOP=true bash "$guard" --repo "$repo" --base main --proved "$proved" --check lint --lane plugin --persona kurapika 2>&1)"; code=$?
if [ "$code" = 0 ] && printf '%s' "$out" | grep -qF "pushed on the strength"; then passed=$((passed+1)); echo "ok    gate 6: publish runs only after gates 1-5"; else failed=$((failed+1)); echo "FAIL  gate 6: expected exit 0, got $code"; printf '%s\n' "$out" | sed 's/^/      /'; fi

echo "publish_gate_fixture: $passed passed, $failed failed"
[ "$failed" = 0 ]
