#!/usr/bin/env bash
# Prove scripts/nen_reach_probe.sh (zheref/hatsu#218): it hands $SHELL exactly ten § 2c's argv
# (-lic, the one program string, nen-probe, the root as $1), closes stdin, passes the shell's exit
# code through untouched, and refuses at 125, spawning nothing, on a bad --root or an empty,
# relative or non-executable $SHELL (bash fills a truly unset SHELL from passwd at startup). Offline
# and hermetic: the "login shell" is a stub under mktemp that records its argv and stdin.

set -euo pipefail
LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
probe="$script_dir/nen_reach_probe.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/nen-reach-probe.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() { echo "nen-reach-probe-fixture: $*" >&2; exit 1; }
pass=0
ok() { pass=$((pass + 1)); echo "ok - $1"; }

root="$fixture_root/hatsu root"; mkdir -p "$root"
log="$fixture_root/argv"; stdin_copy="$fixture_root/stdin"
stub="$fixture_root/stub-shell"
cat > "$stub" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do printf '%s\n' "$a"; done > "$STUB_ARGV"
cat > "$STUB_STDIN"
exit "${STUB_RC:-0}"
STUB
chmod +x "$stub"
printf 'not executable\n' > "$fixture_root/noexec-shell"
export STUB_ARGV="$log" STUB_STDIN="$stdin_copy"

# run EXPECTED_EXIT SHELL_VALUE [VAR=value ...] -- <probe args>; stdin is a non-empty string
run() {
  local expected="$1" shellv="$2"; shift 2
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  rm -f "$log" "$stdin_copy"
  local code=0
  out="$(printf 'LEAKED-STDIN\n' | env ${envs[@]+"${envs[@]}"} SHELL="$shellv" "$probe" "$@" 2>&1)" || code=$?
  [ "$code" = "$expected" ] || fail "expected exit $expected, got $code for '$*' (SHELL=$shellv); output: $out"
}
spawned() { [ -f "$log" ]; }

run 0 "$stub" -- --root "$root"
expected="$(printf '%s\n' -lic 'command -v nen && nen shu tools --repo "$1"' nen-probe "$root")"
[ "$(cat "$log")" = "$expected" ] || fail "argv differs from ten § 2c's line: $(cat "$log")"
ok "the login shell gets ten § 2c's exact argv, the root as \$1 (spaces kept)"

[ ! -s "$stdin_copy" ] || fail "stdin reached the login shell: $(cat "$stdin_copy")"
ok "stdin is /dev/null, never the caller's"

for rc in 1 2 5 7; do run "$rc" "$stub" STUB_RC="$rc" -- --root "$root"; done
ok "the shell's exit code passes through (1, 2, 5, 7)"

run 125 "" -- --root "$root"
spawned && fail "a shell ran with SHELL empty"
run 125 "stub-shell" -- --root "$root"
spawned && fail "a shell ran with a relative SHELL"
run 125 "$fixture_root/noexec-shell" -- --root "$root"
spawned && fail "a non-executable SHELL ran"
ok "an empty, relative or non-executable \$SHELL is 125, nothing spawned (a truly unset one bash fills from passwd)"

run 125 "$stub" --
spawned && fail "a shell ran with no --root"
run 125 "$stub" -- --root
spawned && fail "a shell ran with a valueless --root"
run 125 "$stub" -- --root "$fixture_root/absent"
spawned && fail "a shell ran with an absent --root"
run 125 "$stub" -- --root "$root" --extra
spawned && fail "a shell ran after an extra argument"
ok "a missing, valueless or absent --root and an extra argument are 125, nothing spawned"

echo "nen-reach-probe-fixture: all $pass checks passed"
