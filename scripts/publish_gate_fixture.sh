#!/usr/bin/env bash
# publish_gate_fixture.sh — proves scripts/publish_gate.sh refuses the push at every gate (zheref/hatsu#218).
#
# Lane `publish-gate-guard`: `nen shu test --lane publish-gate-guard --repo <hatsu>`. The nen half is
# stubbed: a `nen` shim on a throwaway PATH (inside this fixture's own temp dir, never shipped) answers
# `wc catch-up`, `shu <check>` and `wc publish` from environment variables (NEN_STUB_NOOP,
# NEN_STUB_CATCHUP_EXIT, NEN_STUB_RED — the one check that is red — and NEN_STUB_PUBLISH) and logs every
# call, so the fixture is hermetic and offline and proves the SCRIPT's chain, never nen. Real git is used
# for the repository, its remote and the authorship check (scripts/branch_authorship_check.sh, with the
# Hatsu-Agent trailer). Each case names its own failure; the needles are the script's own refusal lines,
# never the progress header.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
guard="$here/publish_gate.sh"
tmp="$(mktemp -d)" || { echo "publish_gate_fixture: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$tmp"' EXIT
passed=0; failed=0
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

# the nen shim
mkdir -p "$tmp/bin"
cat > "$tmp/bin/nen" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "${NEN_STUB_LOG:-/dev/null}"
case "$1 $2" in
  "wc catch-up") printf '{\n  "contract": "nen.wc.catch-up/v0.2",\n  "message": "\\"noOp\\": true inside a string value",\n  "noOp": %s\n}\n' "${NEN_STUB_NOOP:-true}"; exit "${NEN_STUB_CATCHUP_EXIT:-0}" ;;
  "shu "*) if [ "$2" = "${NEN_STUB_RED:-}" ]; then echo "stub $2 red"; exit 1; fi; echo "stub $2 ran"; exit 0 ;;
  "wc publish") echo "stub published ($*)"; exit "${NEN_STUB_PUBLISH:-0}" ;;
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
log="$tmp/calls.log"
args=(--repo "$repo" --base main --proved "$proved" --check lint --lane plugin --persona kurapika)
run() { # $1 case, $2 expected exit, $3 needle, $4 'dry'|'real', then env assignments as the remaining args
  name="$1"; want="$2"; needle="$3"; mode="$4"; shift 4
  : > "$log"
  if [ "$mode" = dry ]; then out="$(env NEN_STUB_LOG="$log" "$@" bash "$guard" "${args[@]}" --dry-run 2>&1)"; else out="$(env NEN_STUB_LOG="$log" "$@" bash "$guard" "${args[@]}" 2>&1)"; fi; code=$?
  if [ "$code" = "$want" ] && printf '%s' "$out" | grep -qF -- "$needle"; then passed=$((passed+1)); echo "ok    $name"
  else failed=$((failed+1)); echo "FAIL  $name: expected exit $want carrying '$needle', got exit $code"; printf '%s\n' "$out" | sed 's/^/      /'; fi
}
pushed() { grep -q "^wc publish" "$log"; }

run "every gate yes: a dry run would publish, pushing nothing" 0 "would publish (--dry-run)" dry
grep -q "wc publish --repo .* --dry-run" "$log" && grep -q "wc catch-up .* --dry-run" "$log" && { passed=$((passed+1)); echo "ok    a dry run probes with --dry-run on both nen writes"; } || { failed=$((failed+1)); echo "FAIL  a dry run must pass --dry-run to catch-up and publish"; cat "$log"; }
run "gate 1: catch-up exit 1 refuses" 1 "gate 1" real NEN_STUB_CATCHUP_EXIT=1
pushed && { failed=$((failed+1)); echo "FAIL  gate 1 refusal still pushed"; } || { passed=$((passed+1)); echo "ok    gate 1 refusal pushed nothing"; }
run "gate 1: noOp false refuses (the string decoy does not count)" 1 "noOp is not true" real NEN_STUB_NOOP=false
run "gate 4: a red iteration check refuses" 1 "gate 4" real NEN_STUB_RED=lint
# gate 4 runs EVERY declared check, in order, and a red second check still refuses
: > "$log"; out="$(NEN_STUB_LOG="$log" NEN_STUB_RED=test bash "$guard" --repo "$repo" --base main --proved "$proved" --check lint --check test --lane plugin --persona kurapika 2>&1)"; code=$?
if [ "$code" = 1 ] && grep -q "^shu lint" "$log" && grep -q "^shu test" "$log" && ! pushed; then passed=$((passed+1)); echo "ok    gate 4: two checks run in order and the red second one refuses"; else failed=$((failed+1)); echo "FAIL  gate 4 with two checks: exit $code, log:"; sed 's/^/      /' "$log"; fi
# gate 2: a moved HEAD
git -C "$repo" commit -q --allow-empty -m "$(printf 'chore: moved\n\nHatsu-Agent: kurapika')"
run "gate 2: HEAD past the proved SHA refuses" 1 "gate 2" real
git -C "$repo" reset -q --hard "$proved"
# gate 5: a commit without the trailer
echo c > "$repo/c"; git -C "$repo" add c; git -C "$repo" commit -q -m "feat: no trailer"
bad="$(git -C "$repo" rev-parse HEAD)"
: > "$log"
out="$(NEN_STUB_LOG="$log" bash "$guard" --repo "$repo" --base main --proved "$bad" --check lint --lane plugin --persona kurapika 2>&1)"; code=$?
if [ "$code" = 1 ] && printf '%s' "$out" | grep -qF "gate 5"; then passed=$((passed+1)); echo "ok    gate 5: a commit without the trailer refuses"; else failed=$((failed+1)); echo "FAIL  gate 5: expected exit 1 carrying 'gate 5', got $code"; printf '%s\n' "$out" | sed 's/^/      /'; fi
git -C "$repo" reset -q --hard "$proved"
# gate 3: no upstream, and an upstream that is not the branch's own name
git -C "$repo" branch --unset-upstream
run "gate 3: no upstream refuses" 1 "gate 3" real
git -C "$repo" branch -q -u origin/main
run "gate 3: an upstream that is the trunk refuses" 1 "not '<remote>/fable/kurapika/effort'" real
git -C "$repo" branch -q -u origin/fable/kurapika/effort
# gate 6: the publish itself failing, and a HEAD moved during the gates
run "gate 6: a failing publish is a refusal" 1 "gate 6" real NEN_STUB_PUBLISH=1
cat > "$tmp/bin/nen-mover" <<EOF
#!/usr/bin/env bash
if [ "\$1 \$2" = "shu lint" ]; then git -C "$repo" commit -q --allow-empty -m "\$(printf 'chore: during the gates\n\nHatsu-Agent: kurapika')"; fi
exec "$tmp/bin/nen" "\$@"
EOF
chmod +x "$tmp/bin/nen-mover"
: > "$log"
out="$(NEN="$tmp/bin/nen-mover" NEN_STUB_LOG="$log" bash "$guard" "${args[@]}" 2>&1)"; code=$?
if [ "$code" = 1 ] && printf '%s' "$out" | grep -qF "HEAD moved to" && ! pushed; then passed=$((passed+1)); echo "ok    gate 6: a HEAD that moved during the gates is never pushed"; else failed=$((failed+1)); echo "FAIL  gate 6 race: exit $code"; printf '%s\n' "$out" | sed 's/^/      /'; fi
git -C "$repo" reset -q --hard "$proved"
# wiring: a missing argument, an empty value, a dangling flag, a malformed --proved and --check
for bad_args in "--repo $repo --base main" "--repo  --base main --proved $proved --check lint --lane plugin --persona kurapika" "--repo $repo --base main --proved $proved --check lint --lane plugin --persona" "--repo $repo --base main --proved abc123 --check lint --lane plugin --persona kurapika" "--repo $repo --base main --proved $proved --check 'lint; rm' --lane plugin --persona kurapika"; do
  out="$(eval "bash \"\$guard\" $bad_args" 2>&1)"; code=$?
  if [ "$code" = 2 ]; then passed=$((passed+1)); echo "ok    wiring is exit 2: $bad_args" | cut -c1-80; else failed=$((failed+1)); echo "FAIL  wiring: expected exit 2 for [$bad_args], got $code: $out"; fi
done
# an interrupt mid-chain never pushes and leaves no scratch directory
cat > "$tmp/bin/nen-slow" <<EOF
#!/usr/bin/env bash
if [ "\$1 \$2" = "shu lint" ]; then sleep 3; fi
exec "$tmp/bin/nen" "\$@"
EOF
chmod +x "$tmp/bin/nen-slow"
: > "$log"
# job control on, so the background guard keeps SIGINT's default disposition (a non-interactive shell
# otherwise starts background jobs with SIGINT ignored, and a trap on an ignored signal never fires)
for sig in INT TERM; do
  : > "$log"
  set -m
  NEN="$tmp/bin/nen-slow" NEN_STUB_LOG="$log" bash "$guard" "${args[@]}" >/dev/null 2>&1 & pid=$!
  set +m
  sleep 1; kill -"$sig" "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; code=$?
  if ! pushed && [ "$code" != 0 ]; then passed=$((passed+1)); echo "ok    SIG$sig during gate 4 pushes nothing (exit $code)"; else failed=$((failed+1)); echo "FAIL  SIG$sig: exit $code, pushed=$(pushed && echo yes || echo no)"; fi
done
# the real push, stubbed publish, reaches gate 6 only after gates 1-5
run "gate 6: publish runs only after gates 1-5" 0 "pushed on the strength" real
grep -c "^wc publish" "$log" | grep -qx 1 && { passed=$((passed+1)); echo "ok    exactly one publish call"; } || { failed=$((failed+1)); echo "FAIL  publish calls: $(grep -c '^wc publish' "$log")"; }
# --help prints the whole header
bash "$guard" --help | grep -q "^#   6\." && { passed=$((passed+1)); echo "ok    --help prints the six gates"; } || { failed=$((failed+1)); echo "FAIL  --help is truncated"; }

echo "publish_gate_fixture: $passed passed, $failed failed"
[ "$failed" = 0 ]
