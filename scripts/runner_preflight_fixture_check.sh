#!/usr/bin/env bash
# Hold templates/runner-preflight.yml -- the preflight workflow hatsu:jusshin § 7 renders through
# `nen runner workflow` into every consumer that declares a runner pool -- to the properties that make
# it safe to run on a physical machine (zheref/hatsu, hanten findings C19, N7 and Phinks P1). Each
# conjunct is asserted on its own line with its own FAIL text, first on the LIVE template file, then on
# a rendering of it for two fixture pools:
#
#   on:           exactly workflow_dispatch and push -- no pull_request, no pull_request_target
#   push.paths    exactly one entry, the rendered file itself
#   jobs          one job, preflight, whose `if:` binds github.repository to the one slug
#   runs-on       the pool's labels, exactly (a bare self-hosted is never rendered)
#   permissions   contents: read at the top, none widened on the job
#   checkout      persist-credentials: false
#   time bound    timeout-minutes on the job
#   log hygiene   no step prints the service account's name or a resolved tool path (hanten F5)
#   rendering     no @@PLACEHOLDER@@ left standing
#
# Properties, not bytes: the template is not byte-identical to nen's own test template
# (src/runner/fixtures/runner-preflight.template.yml) since F5, and nothing here compares them.
# Negative cases: a hostile copy that adds pull_request_target and drops the repository binding is
# refused by this guard (nen itself renders it at exit 0 -- the reason this guard exists), a bare
# self-hosted runs-on is refused, and a leftover placeholder is refused by nen at exit 1 with nothing
# written, which jusshin § 7 maps. Needs `nen` (>= 0.18) on PATH, which a lane run through
# `nen shu test` always has; offline, hermetic, writes only under mktemp.
#
# Usage: bash scripts/runner_preflight_fixture_check.sh      exit 0 all hold; 1 a conjunct failed;
#                                                             5 nen could not be started

set -uo pipefail
export LC_ALL=C

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P)"
repo_root="$(CDPATH='' cd -- "$script_dir/.." >/dev/null 2>&1 && pwd -P)"
template="$repo_root/templates/runner-preflight.yml"

[ "$#" -eq 0 ] || { echo "runner-preflight-fixture: takes no arguments" >&2; exit 2; }
[ -f "$template" ] || { echo "runner-preflight-fixture: no template at $template" >&2; exit 2; }
command -v nen >/dev/null 2>&1 || { echo "runner-preflight-fixture: nen could not be started (not on PATH)" >&2; exit 5; }

work="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-runner-preflight.XXXXXX")"
trap 'rm -rf "$work"' EXIT

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "ok:   $*"; }

# block <file> <top-level key>: the lines under `<key>:` up to the next top-level key, comments dropped.
block() {
  awk -v key="$2" '
    /^[[:space:]]*#/ { next }
    $0 ~ "^" key ":[[:space:]]*$" { inside = 1; next }
    inside && /^[^[:space:]]/ { inside = 0 }
    inside { print }
  ' "$1"
}

# children <indent> : the keys at exactly <indent> spaces on stdin, sorted, space-joined.
children() {
  awk -v n="$1" '
    { match($0, /^ */) }
    RLENGTH == n && $0 ~ /^ *[A-Za-z_][A-Za-z0-9_-]*:/ { sub(/^ */, ""); sub(/:.*/, ""); print }
  ' | sort | tr '\n' ' ' | sed 's/ $//'
}

# check <label> <file> <slug> <runs-on> <workflow path> <rendered: yes|no>
check() {
  local label="$1" file="$2" slug="$3" runs_on="$4" wf_path="$5" rendered="$6" on_block got code

  if grep -Eq '^on:[[:space:]]*$' "$file"; then
    pass "$label: on: is a block"
  else
    fail "$label: on: is not a block mapping (an inline or missing trigger set is not reviewable here)"
  fi

  on_block="$(block "$file" on)"
  got="$(printf '%s\n' "$on_block" | children 2)"
  if [ "$got" = "push workflow_dispatch" ]; then
    pass "$label: the event set is exactly workflow_dispatch and push"
  else
    fail "$label: the event set is '$got', not exactly 'push workflow_dispatch'"
  fi

  code="$(grep -Ev '^[[:space:]]*#' "$file")"
  case "$code" in
    *pull_request*) fail "$label: pull_request or pull_request_target appears outside a comment -- a fork's PR head would define the job" ;;
    *) pass "$label: no pull_request and no pull_request_target" ;;
  esac

  got="$(printf '%s\n' "$on_block" | awk '/^  push:/ { p = 1; next } /^  [^ ]/ { p = 0 } p' | children 4)"
  if [ "$got" = "paths" ]; then
    pass "$label: push carries a paths filter and nothing else"
  else
    fail "$label: push's filters are '$got', not exactly 'paths'"
  fi
  got="$(printf '%s\n' "$on_block" | awk '/^  push:/ { p = 1; next } /^  [^ ]/ { p = 0 } p && /^      - / { sub(/^      - /, ""); print }')"
  if [ "$got" = "'$wf_path'" ]; then
    pass "$label: push.paths holds only the file itself"
  else
    fail "$label: push.paths is [$got], not exactly ['$wf_path']"
  fi

  got="$(block "$file" jobs | children 2)"
  if [ "$got" = "preflight" ]; then
    pass "$label: the one job is preflight"
  else
    fail "$label: the jobs are '$got', not exactly 'preflight'"
  fi

  if grep -Fxq "    if: github.repository == '$slug'" "$file"; then
    pass "$label: the job is bound to $slug"
  else
    fail "$label: no job-level 'if: github.repository == '$slug'' -- a fork that enables Actions would run it"
  fi

  if grep -Fxq "    runs-on: $runs_on" "$file"; then
    pass "$label: runs-on is exactly $runs_on"
  else
    fail "$label: runs-on is not exactly '$runs_on'"
  fi

  got="$(block "$file" permissions | sed 's/[[:space:]]*$//')"
  if [ "$got" = "  contents: read" ]; then
    pass "$label: the token is contents: read and nothing else"
  else
    fail "$label: top-level permissions are not exactly 'contents: read'"
  fi
  if grep -Eq '^ {4,}permissions:' "$file"; then
    fail "$label: a job or step widens permissions"
  else
    pass "$label: no job-level permissions"
  fi

  if grep -Eq '^[[:space:]]+persist-credentials: false[[:space:]]*$' "$file"; then
    pass "$label: checkout does not persist the credential"
  else
    fail "$label: no 'persist-credentials: false' on the checkout"
  fi

  if grep -Eq '^    timeout-minutes: [1-9][0-9]*[[:space:]]*$' "$file"; then
    pass "$label: the job carries a timeout-minutes bound"
  else
    fail "$label: the job carries no timeout-minutes bound"
  fi

  if printf '%s\n' "$code" | grep -Eq '(echo|printf)[^#]*\$\{?(USERNAME|USER|LOGNAME|acct|resolved|path)\b'; then
    fail "$label: a step prints the service account's name or a resolved tool path (a public log)"
  else
    pass "$label: no step prints an account name or a resolved path"
  fi

  if [ "$rendered" = yes ]; then
    if grep -q '@@' "$file"; then
      fail "$label: a placeholder is left standing: $(grep -o '@@[A-Z_]*@@' "$file" | sort -u | tr '\n' ' ')"
    else
      pass "$label: no placeholder left"
    fi
  fi
}

# consumer <dir>: a throwaway consumer declaring two pools, one Windows, one macOS.
consumer() {
  mkdir -p "$1/nen"
  cat > "$1/nen/workflow.json" <<'JSON'
{
  "runners": {
    "naming": "{machine}-{consumer}R{slot}",
    "pools": [
      { "id": "windows-x64", "os": "Windows", "arch": "X64", "labels": ["self-hosted", "Windows", "X64"],
        "enableVariable": "FIXTURE_WINDOWS_RUNNER", "tools": ["git", "bash", "gh"],
        "preflightWorkflow": "runner-preflight-windows-x64.yml" },
      { "id": "macos-arm64", "os": "macOS", "arch": "ARM64", "labels": ["self-hosted", "macOS", "ARM64"],
        "tools": ["git", "bash"], "preflightWorkflow": "runner-preflight-macos-arm64.yml" }
    ]
  }
}
JSON
}

# render <template> <pool> <out>: sets $render_code and $render_out
render() {
  render_out="$(nen runner workflow --repo "$work/consumer" --pool "$2" --target fixture-owner/fixture-repo \
    --template "$1" --out "$3" --json 2>&1)"
  render_code=$?
}

slug=fixture-owner/fixture-repo
consumer "$work/consumer"

# 1. The live template itself.
check "template" "$template" '@@REPO_SLUG@@' '@@RUNS_ON@@' '.github/workflows/@@WORKFLOW_FILE@@' no

# 2. Its rendering for each fixture pool.
for pool in windows-x64 macos-arm64; do
  case "$pool" in
    windows-x64) runs_on='[self-hosted, Windows, X64]' ;;
    macos-arm64) runs_on='[self-hosted, macOS, ARM64]' ;;
  esac
  render "$template" "$pool" "$work/$pool.yml"
  if [ "$render_code" -eq 0 ] && [ -f "$work/$pool.yml" ]; then
    pass "render $pool: nen runner workflow exit 0"
    check "render $pool" "$work/$pool.yml" "$slug" "$runs_on" ".github/workflows/runner-preflight-$pool.yml" yes
  else
    fail "render $pool: nen runner workflow exit $render_code: $render_out"
  fi
done

# 3. Negative: a hostile copy -- pull_request_target added, the repository binding dropped. nen renders
# it (exit 0); this guard must refuse both the copy and its rendering, each conjunct by name.
hostile="$work/hostile.yml"
awk '{ print } /^on:[[:space:]]*$/ { print "  pull_request_target:" }' "$template" \
  | grep -Fv "    if: github.repository == '@@REPO_SLUG@@'" > "$hostile"
for target in template rendering; do
  file="$hostile"
  expect_slug='@@REPO_SLUG@@'
  if [ "$target" = rendering ]; then
    render "$hostile" windows-x64 "$work/hostile-rendered.yml"
    [ "$render_code" -eq 0 ] || { fail "negative: nen refused the hostile copy (exit $render_code), so it is not the case this guard exists for: $render_out"; continue; }
    file="$work/hostile-rendered.yml"
    expect_slug="$slug"
  fi
  before=$failures
  neg="$(check "hostile $target" "$file" "$expect_slug" '[self-hosted, Windows, X64]' '.github/workflows/runner-preflight-windows-x64.yml' no)"
  failures=$before
  for needle in 'the event set is' 'pull_request or pull_request_target appears' "no job-level 'if: github.repository"; do
    case "$neg" in
      *"FAIL: hostile $target: $needle"*) pass "negative ($target): refused -- $needle" ;;
      *) fail "negative ($target): the hostile copy was not refused on '$needle': $neg" ;;
    esac
  done
done

# 4. Negative: a bare self-hosted runs-on is refused.
bare="$work/bare.yml"
sed 's/^    runs-on: .*/    runs-on: [self-hosted]/' "$work/windows-x64.yml" > "$bare"
before=$failures
neg="$(check "bare" "$bare" "$slug" '[self-hosted, Windows, X64]' '.github/workflows/runner-preflight-windows-x64.yml' yes)"
failures=$before
case "$neg" in
  *"FAIL: bare: runs-on is not exactly"*) pass "negative: a bare self-hosted runs-on is refused" ;;
  *) fail "negative: a bare self-hosted runs-on was not refused: $neg" ;;
esac

# 5. Negative: a leftover placeholder is nen's exit 1, nothing written.
leftover="$work/leftover.yml"
sed 's/^name: runner-preflight-@@POOL_ID@@$/name: runner-preflight-@@POOL_ID@@-@@BOGUS@@/' "$template" > "$leftover"
render "$leftover" windows-x64 "$work/leftover-rendered.yml"
if [ "$render_code" -eq 1 ] && [ ! -e "$work/leftover-rendered.yml" ]; then
  pass "negative: a leftover placeholder is nen's exit 1 and nothing is written"
else
  fail "negative: a leftover placeholder answered exit $render_code (written: $([ -e "$work/leftover-rendered.yml" ] && echo yes || echo no)): $render_out"
fi

if [ "$failures" -eq 0 ]; then
  echo "runner-preflight: every property holds"
  exit 0
fi
echo "runner-preflight: $failures conjunct(s) failed"
exit 1
