#!/usr/bin/env bash
# Prove scripts/gh_token_env.sh (zheref/hatsu#218): the token `gh auth token` prints reaches the one
# command named and is never printed by the wrapper; the command's own exit code passes through; the
# wrapper's own failures (usage, a refused --path, no gh, a failed or empty token) are exit 125 with
# the command NOT run; a missing command is 127; --path prepends exactly one directory; arguments
# with spaces survive. Offline and hermetic: a stub `gh` and a stub probe under mktemp, a PATH of
# the stub directory plus /usr/bin:/bin only.

set -euo pipefail
LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
wrapper="$script_dir/gh_token_env.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/gh-token-env.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() { echo "gh-token-env-fixture: $*" >&2; exit 1; }
pass=0
ok() { pass=$((pass + 1)); echo "ok - $1"; }

bin="$fixture_root/bin"; nogh="$fixture_root/nogh"; extra="$fixture_root/extra dir"
mkdir -p "$bin" "$nogh" "$extra"
token_value="fixture-token-value-218"

# The stub gh: STUB_GH_MODE=ok prints the token, empty prints nothing, fail exits 1.
cat > "$bin/gh" <<'STUB'
#!/usr/bin/env bash
[ "${1:-} ${2:-}" = "auth token" ] || { echo "stub gh: unexpected '$*'" >&2; exit 9; }
case "${STUB_GH_MODE:-ok}" in
  ok) printf '%s\n' "$STUB_TOKEN" ;;
  empty) : ;;
  fail) echo "stub gh: not logged in" >&2; exit 1 ;;
esac
STUB
# The probe: records that it ran, whether GH_TOKEN equals the expected value (never the value
# itself), PATH's first entry and its argument count and arguments; exits PROBE_RC.
cat > "$bin/probe" <<'STUB'
#!/usr/bin/env bash
: > "$PROBE_RAN"
if [ "${GH_TOKEN:-}" = "$STUB_TOKEN" ]; then echo "token: match"; else echo "token: mismatch"; fi
echo "path0: ${PATH%%:*}"
echo "argc: $#"
for a in "$@"; do echo "arg: $a"; done
exit "${PROBE_RC:-0}"
STUB
chmod +x "$bin/gh" "$bin/probe"
cp "$bin/probe" "$extra/probe"
printf 'not executable\n' > "$bin/noexec"

export STUB_TOKEN="$token_value" PROBE_RAN="$fixture_root/ran"

# run EXPECTED_EXIT PATH_VALUE [VAR=value ...] -- <wrapper args> ; output in $out
run() {
  local expected="$1" pathv="$2"; shift 2
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  rm -f "$PROBE_RAN"
  local code=0
  out="$(env ${envs[@]+"${envs[@]}"} PATH="$pathv" "$wrapper" "$@" 2>&1)" || code=$?
  [ "$code" = "$expected" ] || fail "expected exit $expected, got $code for '$*'; output: $out"
  case "$out" in *"$token_value"*) fail "the token value was printed for '$*'" ;; esac
}
ran() { [ -f "$PROBE_RAN" ]; }

base="$bin:/usr/bin:/bin"

run 0 "$base" -- probe
ran || fail "the probe did not run"
case "$out" in *"token: match"*) ;; *) fail "GH_TOKEN did not reach the command: $out" ;; esac
ok "the token from 'gh auth token' reaches the command, never printed"

run 0 "$base" GH_TOKEN=some-other-ambient-value -- probe
case "$out" in *"token: match"*) ;; *) fail "an ambient GH_TOKEN overrode gh's answer: $out" ;; esac
ok "the token is always gh's answer"

for rc in 1 3 7 8; do run "$rc" "$base" PROBE_RC="$rc" -- probe; done
ok "the command's own exit codes pass through (1, 3, 7, 8)"

run 0 "$base" -- probe "two words" --flag=x ''
case "$out" in *"argc: 3"*"arg: two words"*"arg: --flag=x"*) ;; *) fail "arguments were not preserved: $out" ;; esac
ok "arguments with spaces and empty strings survive"

run 0 "$base" -- -- probe
ran || fail "'--' did not end the options"
ok "'--' ends the options"

run 0 "$base" -- --path "$extra" probe
case "$out" in *"path0: $extra"*) ;; *) fail "--path was not prepended: $out" ;; esac
ok "--path prepends one absolute directory (spaces kept)"

run 125 "$base" -- --path "relative/dir" probe
ran && fail "the command ran under a relative --path"
run 125 "$base" -- --path "$fixture_root/absent" probe
ran && fail "the command ran under a missing --path"
run 125 "$base" -- --path
run 125 "$base" -- --path "$extra:/usr/bin" probe
ran && fail "the command ran under a --path carrying ':'"
ok "a relative, missing, valueless or ':'-carrying --path is refused at 125, nothing run"

# Tracing never prints the token: SHELLOPTS=xtrace and `bash -x` both reach the wrapper.
rm -f "$PROBE_RAN"
code=0; out="$(env PATH="$base" SHELLOPTS=xtrace "$wrapper" probe 2>&1)" || code=$?
[ "$code" = 0 ] || fail "the wrapper under SHELLOPTS=xtrace exited $code: $out"
case "$out" in *"$token_value"*) fail "SHELLOPTS=xtrace printed the token" ;; esac
code=0; out="$(env PATH="$base" bash -x "$wrapper" probe 2>&1)" || code=$?
[ "$code" = 0 ] || fail "the wrapper under bash -x exited $code: $out"
case "$out" in *"$token_value"*) fail "bash -x printed the token" ;; esac
ok "SHELLOPTS=xtrace and bash -x never print the token"

# A command whose name begins with '-' is the command, never exec's own flag.
cp "$bin/probe" "$bin/-c"
run 0 "$base" -- -- -c
ran || fail "a command named -c did not run"
ok "a command named -c runs as the command"

run 125 "$base" --
case "$out" in *"no command given"*) ;; *) fail "no-command refusal not named: $out" ;; esac
run 125 "$base" -- --bogus probe
ran && fail "the command ran after an unknown option"
ok "usage refusals are 125 and name the shape"

run 125 "$base" STUB_GH_MODE=fail -- probe
ran && fail "the command ran when gh auth token failed"
case "$out" in *"gh auth status"*) ;; *) fail "the failed-token refusal does not name 'gh auth status': $out" ;; esac
run 125 "$base" STUB_GH_MODE=empty -- probe
ran && fail "the command ran with an empty token"
ok "a failed or empty 'gh auth token' is 125, the fix named, nothing run"

cp "$bin/probe" "$nogh/probe"
run 125 "$nogh:/usr/bin:/bin" -- probe
ran && fail "the command ran with no gh on PATH"
ok "no gh on PATH is 125, nothing run"

run 127 "$base" -- no-such-command-218
run 126 "$base" -- "$bin/noexec"
ok "a missing command is 127, a non-executable one 126"

echo "gh-token-env-fixture: all $pass checks passed"
