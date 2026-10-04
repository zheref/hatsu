#!/usr/bin/env bash
# Hold templates/runner-preflight.yml -- the preflight workflow hatsu:jusshin § 7 renders through
# `nen runner workflow` into every consumer that declares a runner pool -- to the properties that make
# it safe to run on a physical machine (zheref/hatsu, hanten findings C19, N7 and Phinks P1). Each
# conjunct is asserted on its own line with its own FAIL text, first on the LIVE template file, then on
# a rendering of it for two fixture pools:
#
#   on:           exactly workflow_dispatch and push -- no pull_request, no pull_request_target
#   push          exactly branches and paths: branches holds only '**' (every branch, no tag -- GitHub
#                 evaluates no paths filter on a tag push, so paths alone wakes the pool on every tag;
#                 zheref/hatsu#198 item 1, Phinks QA-17), paths holds only the rendered file itself
#   jobs          one job, preflight, whose `if:` binds github.repository to the one slug
#   runs-on       the pool's labels, exactly (a bare self-hosted is never rendered)
#   permissions   contents: read at the top, none widened on the job
#   checkout      persist-credentials: false
#   pins          every uses: pinned by a 40-hex commit SHA with an exact dotted '# vN.N(.N)' tag
#                 comment -- a bare '# vN' names a moving major alias (Feitan SEC-14; #198 item 5)
#   time bound    timeout-minutes on the job
#   log hygiene   no line of the job's own prints the service account's name, a resolved tool path or the
#                 PATH (hanten F5); a tool's `--version` output is the tool's and is not held here
#   rendering     no @@PLACEHOLDER@@ left standing
#   appdata       the Windows step normalises with nen's two-backslash form, and, lifted from the live
#                 template and its rendering and run against a stubbed where.exe printing CRLF lines,
#                 classifies the FIRST match only: AppData and the rest of $USERPROFILE fail, Program
#                 Files passes over a stale later AppData match, no match is not on the service PATH,
#                 and no path is ever printed (Feitan BC-9, Nobunaga; Copilot on zheref/nen#318)
#   recording     the cmd step is exactly `chcp 65001 >nul` then `(set PATH) > "%RUNNER_TEMP%\service-path.txt"`
#                 -- UTF-8 first, or a non-ASCII directory on the service PATH reads as absent (Phinks P2)
#   service path  the Windows step classifies against the PATH the cmd step before it recorded under
#                 RUNNER_TEMP (`$SERVICE_PATH:<tool>`), never Git Bash's own: a tool present only under
#                 Git's mingw64\bin reads not on the service PATH and fails, and a missing recording
#                 fails the step instead of classifying against nothing (#198 item 2, Phinks QA-18)
#   exec probe    a machine-wide match is RUN (--version, output discarded) before it reads machine-wide:
#                 the step's lifted body runs a real stub executable whose exit the harness sets, and a 126
#                 reads "machine-wide, refused on exec (exit 126)", any other non-zero "machine-wide,
#                 exited N", both failing with the tool and the MACHINE PATH named (Copilot on #202)
#   remedy        no ::error:: line names a tool-templated install path or Program Files, and every
#                 per-user remedy names the tool and the MACHINE PATH (Copilot on zheref/nen#320 and
#                 zheref/hatsu#179)
#   desktop       (zheref/hatsu#206, nen 0.19's interactive mode) a third fixture pool, interactive Windows,
#                 renders with runs-on [self-hosted, Windows, X64, desktop] and MODE 'interactive' on the
#                 toolchain and Windows steps; the session probe's `if:` is exactly
#                 `runner.os == 'Windows' && '@@MODE@@' == 'interactive'` on the template and a constant
#                 on every rendering ('service' == 'interactive' for the service pool); lifted and run
#                 against a stubbed powershell.exe, it fails session 0 and an unknown session and passes a
#                 desktop session, printing the id and no account; and the Windows step, lifted and run
#                 with MODE=interactive, warns on a per-user match instead of failing, still fails a
#                 missing or refused one, and names the sign-in as the restart
#
# Properties, not bytes: the template is not byte-identical to nen's own test template
# (src/runner/fixtures/runner-preflight.template.yml) since F5, and nothing here compares them.
# Negative cases: a hostile copy that adds pull_request_target and drops the repository binding is
# refused by this guard (nen itself renders it at exit 0 -- the reason this guard exists), a bare
# self-hosted runs-on is refused, a push that admits a tag ref -- `paths:` alone (the shape before
# #198) or a `tags:` filter beside it -- is refused, and a leftover placeholder is refused by nen at
# exit 1 with nothing written, which jusshin § 7 maps. Needs `nen` (>= 0.19: MODE and the desktop pool) on PATH, which a lane run
# through `nen shu test` always has; offline, hermetic, writes only under mktemp.
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
  if [ "$got" = "branches paths" ]; then
    pass "$label: push carries a branches filter and a paths filter and nothing else"
  else
    fail "$label: push's filters are '$got', not exactly 'branches paths' -- without branches a tag push is admitted (GitHub evaluates no paths filter on a tag push), and tags/tags-ignore admit tag refs"
  fi
  # push_list <key>: the `- ` entries under push.<key>, in order.
  push_list() {
    printf '%s\n' "$on_block" | awk -v key="$1" '
      /^  push:/ { p = 1; next } /^  [^ ]/ { p = 0 }
      p && $0 ~ "^    " key ":" { k = 1; next } p && /^    [^ ]/ { k = 0 }
      p && k && /^      - / { sub(/^      - /, ""); print }'
  }
  got="$(push_list branches)"
  if [ "$got" = "'**'" ]; then
    pass "$label: push.branches holds only '**' (every branch, no tag ref)"
  else
    fail "$label: push.branches is [$got], not exactly ['**']"
  fi
  got="$(push_list paths)"
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
  # NOT YET HELD: the maintainer's ruling of 2026-10-02 on zheref/hatsu#198 item 6 -- a pool's labels
  # carry one of the pool's own, because GitHub's defaults (self-hosted, the OS, the arch) are what every
  # runner of that OS and arch gets at registration, so a rendering whose runs-on is the defaults alone
  # admits any later registration into the pool unproven. nen's schema refuses a fourth label at exit 2
  # ("a pool's labels are exactly [self-hosted, <os>, <arch>]"), citing this repository's own
  # runner-policy guard, so the conjunct cannot be rendered until nen's schema, the Ruby guard and
  # tenkai's runner derivation admit a pool-own label together: zheref/hatsu#204. A conjunct that cannot
  # run is not written as one.

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

  got="$(grep -E '^[[:space:]]*(- )?uses:' "$file")"
  if [ -z "$got" ]; then
    fail "$label: no uses: line at all (the checkout step is gone)"
  elif printf '%s\n' "$got" | grep -Evq '^[[:space:]]*(- )?uses: [A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40} # v[0-9]+(\.[0-9]+)+[[:space:]]*$'; then
    fail "$label: a uses: is not pinned by a 40-hex commit SHA with an exact dotted '# vN.N(.N)' tag comment (SEC-14; a bare '# vN' names a moving major alias): $(printf '%s\n' "$got" | grep -Ev '@[0-9a-f]{40} # v[0-9]+(\.[0-9]+)+[[:space:]]*$' | sed 's/^[[:space:]]*//' | tr '\n' ' ')"
  else
    pass "$label: every uses: is pinned by a 40-hex SHA with an exact dotted '# vN.N(.N)' tag comment"
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

  # The cmd recording step, exactly: UTF-8 code page first (cmd writes a redirected file in the console's
  # OEM code page, so a non-ASCII directory on the service PATH came back as bytes where.exe could not
  # match and read as not on the service PATH -- Phinks P2 on zheref/hatsu#198), then `set PATH` into the
  # file under RUNNER_TEMP. Not lifted and run: cmd.exe is not a fixture dependency.
  got="$(awk '/^      - name: Record the PATH the service hands a job \(Windows\)/ { s = 1 }
              s && /^        run: \|/ { r = 1; next }
              r && /^          / { sub(/^          /, ""); print; next }
              r { exit }' "$file" | tr '\n' '|')"
  if [ "$got" = 'chcp 65001 >nul|(set PATH) > "%RUNNER_TEMP%\service-path.txt"|' ]; then
    pass "$label: the cmd step sets the UTF-8 code page, then records 'set PATH' under RUNNER_TEMP"
  else
    fail "$label: the cmd recording step is [$got], not exactly 'chcp 65001 >nul' then '(set PATH) > \"%RUNNER_TEMP%\\service-path.txt\"'"
  fi

  if [ "$rendered" = yes ]; then
    if grep -q '@@' "$file"; then
      fail "$label: a placeholder is left standing: $(grep -o '@@[A-Z_]*@@' "$file" | sort -u | tr '\n' ' ')"
    else
      pass "$label: no placeholder left"
    fi
  fi
}

# consumer <dir>: a throwaway consumer declaring three pools: a Windows service pool, a macOS one, and an
# interactive Windows pool (nen 0.19: mode interactive, the fourth label desktop).
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
        "tools": ["git", "bash"], "preflightWorkflow": "runner-preflight-macos-arm64.yml" },
      { "id": "windows-x64-desktop", "os": "Windows", "arch": "X64", "mode": "interactive",
        "labels": ["self-hosted", "Windows", "X64", "desktop"], "enableVariable": "FIXTURE_DESKTOP_RUNNER",
        "tools": ["git", "bash", "gh"], "preflightWorkflow": "runner-preflight-windows-x64-desktop.yml" }
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
for pool in windows-x64 macos-arm64 windows-x64-desktop; do
  case "$pool" in
    windows-x64) runs_on='[self-hosted, Windows, X64]' ;;
    macos-arm64) runs_on='[self-hosted, macOS, ARM64]' ;;
    windows-x64-desktop) runs_on='[self-hosted, Windows, X64, desktop]' ;;
  esac
  render "$template" "$pool" "$work/$pool.yml"
  if [ "$render_code" -eq 0 ] && [ -f "$work/$pool.yml" ]; then
    pass "render $pool: nen runner workflow exit 0"
    check "render $pool" "$work/$pool.yml" "$slug" "$runs_on" ".github/workflows/runner-preflight-$pool.yml" yes
  else
    fail "render $pool: nen runner workflow exit $render_code: $render_out"
  fi
done

# 2b. The Windows AppData step, lifted whole out of the LIVE template and out of its rendering, and run
# (Feitan BC-9 and Nobunaga on zheref/nen's rendering: the template carried `${line//\//}` -- ONE
# backslash, so the pattern was a literal '/', where.exe's backslashes stood, */appdata/* never matched
# and the step could only pass). The normalisation must be nen's own fixture's two-backslash form, and
# the step, with where.exe stubbed as a shell function printing CRLF-terminated lines, must fail a
# backslash and a forward-slash path under AppData, pass a Program Files path, and never print the
# path. Copilot's review of zheref/nen#318 added the rest: only the FIRST where.exe line is what a job
# runs, so a stale later AppData match must not fail a Program Files first match; anywhere else under
# $USERPROFILE (scoop shims, a profile bin) is per-user too, matched without regard to case; and no
# line at all is 'not found'. Placeholder account names only.
norm_lines="$(grep -E '^[[:space:]]*(norm|profile)=.*\\' "$template" | sed 's/^[[:space:]]*//')"
want_norm="$(printf '%s\n' 'profile="${profile//\\//}"' 'norm="${first//\\//}"')"
if [ "$norm_lines" = "$want_norm" ]; then
  pass "appdata step: the template normalises the first match and the profile with the two-backslash \${x//\\\\//}"
else
  fail "appdata step: the template's normalisation is [$norm_lines], not exactly [$want_norm] (BC-9)"
fi
if grep -Fq '//\//}' "$template"; then
  fail "appdata step: a one-backslash \${x//\\//} (deletes '/', keeps '\\') is in the template (BC-9)"
else
  pass "appdata step: no one-backslash \${x//\\//} is present"
fi
# step_body <file> : the run: block of the Windows resolution step, de-indented.
step_body() {
  awk '
    /^      - name: Resolution must be machine-wide \(Windows\)/ { s = 1; next }
    s && /^      - / { exit }
    s && /^        run: \|/ { r = 1; next }
    r && /^[^ ]/ { exit }
    r && /^        [^ ]/ { exit }
    r { sub(/^          /, ""); print }
  ' "$1"
}
# The recording the cmd step leaves under RUNNER_TEMP (zheref/hatsu#198 item 2): `set PATH` output, CRLF,
# `Path=` first and `PATHEXT=` after it. The step must read the Path line back and export it as
# SERVICE_PATH; the stub below answers the `$SERVICE_PATH:` form ONLY when that export equals this
# recording, so a step that searched anything else -- Git Bash's own PATH, the current directory -- is
# answered as it would be on a host: with Git's own tools, or with nothing.
stub_recorded='C:\svc\bin;C:\Windows\system32'
mkdir -p "$work/runner-temp" "$work/empty-temp"
printf 'Path=%s\r\nPATHEXT=.COM;.EXE;.BAT;.CMD\r\n' "$stub_recorded" > "$work/runner-temp/service-path.txt"
# The where.exe stub, prepended to every lifted step. It reads SERVICE_PATH from the EXPORTED environment
# (printenv), as the real where.exe would: a shell function also sees an unexported variable, so a step
# that dropped `export` would pass a variable-reading stub here and fail on a host (Nobunaga N4 on
# zheref/hatsu#198; 2d below holds that mutant).
# A machine-wide match is RUN by the step (where.exe locates, it never executes -- Copilot on
# zheref/hatsu#202: Git Bash's own copy can answer the toolchain step while the service's match is
# broken or refused), so the machine-wide answers below point at this real stub executable, whose exit
# is STUB_EXEC_RC: 0 is a working install, 126 the ACL refusal, anything else a broken one.
mkdir -p "$work/mw"
printf '#!/bin/sh\nexit "${STUB_EXEC_RC:-0}"\n' > "$work/mw/gh.exe"
chmod +x "$work/mw/gh.exe"
mw_gh="$work/mw/gh.exe"
cat > "$work/where-stub.sh" <<'STUB'
where.exe() {
  local l list=""
  case "$1" in
    '$SERVICE_PATH:'*) [ "$(printenv SERVICE_PATH 2>/dev/null)" = "$STUB_RECORDED" ] && list="${STUB_PATH:-}" ;;
    '$PATH:'*) list="${STUB_BASH_PATH:-${STUB_PATH:-}}" ;;
    *) printf '%s\r\n' 'C:\a\checkout\gh.exe'; list="${STUB_BASH_PATH:-${STUB_PATH:-}}" ;;
  esac
  while IFS= read -r -d ';' l; do printf '%s\r\n' "$l"; done <<< "${list:+$list;}"
}
STUB
for src in template rendering; do
  from="$template"; [ "$src" = rendering ] && from="$work/windows-x64.yml"
  step="$work/appdata-step-$src.sh"
  # The stub prints each ';'-separated entry of the list it selects as one CRLF line, in order, and
  # nothing when the list is empty -- the PATH search. `$SERVICE_PATH:<tool>` is the service's PATH
  # (STUB_PATH), answered only when the step exported the recording; `$PATH:<tool>` is Git Bash's own
  # PATH (STUB_BASH_PATH, else STUB_PATH -- the pre-#198 template searched this and read Git's own
  # curl as machine-wide); and, like the real where.exe, a bare `where.exe <tool>` searches the current
  # directory FIRST, where the job just checked the repository out, so it prints a checkout-local
  # C:\a\checkout\gh.exe ahead of Git Bash's lines (Copilot on zheref/hatsu#178). Every case below
  # therefore also proves the step calls `where.exe "\$SERVICE_PATH:<tool>"` with the recording exported.
  { cat "$work/where-stub.sh"; step_body "$from"; } > "$step"
  grep -q 'appdata' "$step" || { fail "appdata step ($src): the Windows resolution step was not found"; continue; }
  # <USERPROFILE, '-' = unset>|<service PATH where.exe lines, ';'-separated; MW = the stub executable>|<Git Bash-only lines>|<the stub executable's exit>|<exit>|<first output line>[|<case name>]
  for probe in 'C:\Users\x|C:\Users\x\AppData\Local\Programs\gh\gh.exe||0|1|gh: per-user (AppData)' \
               'C:\Users\x|C:/Users/x/AppData/Local/gh.exe||0|1|gh: per-user (AppData)' \
               'C:\Users\x|MW||0|0|gh: machine-wide' \
               'C:\Users\x|MW;C:\Users\x\AppData\Local\gh.exe||0|0|gh: machine-wide' \
               'C:\Users\x|C:\Users\x\scoop\shims\gh.exe||0|1|gh: per-user (profile)' \
               '-|C:\Users\x\AppData\Local\Programs\gh\gh.exe||0|1|gh: per-user (AppData)' \
               '-|MW||0|0|gh: machine-wide' \
               'c:\users\X|C:\Users\x\bin\gh.exe||0|1|gh: per-user (profile)' \
               'C:\Users\x||||1|gh: not on the service PATH' \
               'C:\Users\x|C:\Users\x\AppData\Local\Programs\gh\gh.exe||0|1|gh: per-user (AppData)|a checkout-local same-named gh.exe must not hide the per-user one on PATH ($SERVICE_PATH: form)' \
               'C:\Users\x||C:\Program Files\Git\mingw64\bin\gh.exe|0|1|gh: not on the service PATH|a tool present only under Git Bash'"'"'s mingw64\bin is not on the service PATH (#198 item 2)' \
               'C:\Users\x|C:\Users\x\AppData\Local\Programs\gh\gh.exe|C:\Program Files\Git\mingw64\bin\gh.exe|0|1|gh: per-user (AppData)|the service PATH decides, not Git Bash'"'"'s first match (a per-user tool that Git Bash shadows machine-wide)' \
               'C:\Users\x|MW|C:\Program Files\Git\mingw64\bin\gh.exe|126|1|gh: machine-wide, refused on exec (exit 126)|a machine-wide match the service account cannot execute, shadowed by Git Bash'"'"'s copy (Copilot on #202)' \
               'C:\Users\x|MW|C:\Program Files\Git\mingw64\bin\gh.exe|3|1|gh: machine-wide, exited 3|a broken machine-wide install shadowed by Git Bash'"'"'s copy (Copilot on #202)'; do
    prof="${probe%%|*}" rest="${probe#*|}"
    path="${rest%%|*}" rest="${rest#*|}"
    bash_path="${rest%%|*}" rest="${rest#*|}"
    exec_rc="${rest%%|*}" rest="${rest#*|}"
    want_code="${rest%%|*}" rest="${rest#*|}"
    want="${rest%%|*}" name=""
    [ "$want" != "$rest" ] && name=" [${rest#*|}]"
    path="${path//MW/$mw_gh}"
    if [ "$prof" = - ]; then
      out="$(env -u USERPROFILE RUNNER_TEMP="$work/runner-temp" STUB_RECORDED="$stub_recorded" STUB_PATH="$path" STUB_BASH_PATH="$bash_path" STUB_EXEC_RC="${exec_rc:-0}" TOOLS=gh bash "$step" 2>&1)"
    else
      out="$(USERPROFILE="$prof" RUNNER_TEMP="$work/runner-temp" STUB_RECORDED="$stub_recorded" STUB_PATH="$path" STUB_BASH_PATH="$bash_path" STUB_EXEC_RC="${exec_rc:-0}" TOOLS=gh bash "$step" 2>&1)"
    fi
    code=$?
    first="$(printf '%s\n' "$out" | head -n 1)"
    case "$out" in
      *'Users\x'*|*'Users/x'*|*'users/x'*|*'users\x'*|*'Users\X'*|*'users\X'*|*'svc\bin'*|*'svc/bin'*|*"$work"*) printed=yes ;;
      *) printed=no ;;
    esac
    if [ "$code" = "$want_code" ] && [ "$first" = "$want" ] && [ "$printed" = no ]; then
      pass "appdata step ($src)$name: USERPROFILE=$prof, service [${path//$mw_gh/MW}], git-bash [$bash_path], exec rc ${exec_rc:-0} (CRLF) -> exit $code, '$want', no path printed"
    else
      fail "appdata step ($src)$name: USERPROFILE=$prof, service [${path//$mw_gh/MW}], git-bash [$bash_path], exec rc ${exec_rc:-0} -> exit $code '$first' (path printed: $printed), not exit $want_code '$want' with no path printed"
    fi
  done
  # No recording at all (the cmd step did not run, or wrote nothing): the step fails by name rather than
  # classifying every tool against an empty PATH as 'not on the service PATH'.
  out="$(USERPROFILE='C:\Users\x' RUNNER_TEMP="$work/empty-temp" STUB_RECORDED="$stub_recorded" STUB_PATH='C:\Windows\system32\gh.exe' TOOLS=gh bash "$step" 2>&1)"
  code=$?
  case "$out" in
    *'::error::'*'was not recorded'*) seen=yes ;;
    *) seen=no ;;
  esac
  if [ "$code" -eq 1 ] && [ "$seen" = yes ]; then
    pass "appdata step ($src) [no recording]: exit 1 naming the missing recording, nothing classified"
  else
    fail "appdata step ($src) [no recording]: exit $code (named: $seen), not exit 1 naming the missing recording: $out"
  fi
done

# 2d. Negative: a step that reads the recording but does not EXPORT it. The real where.exe reads the
# environment ("Environment variable SERVICE_PATH is not found", exit 1), so such a step classifies every
# tool as not on the service PATH; the printenv-reading stub must refuse it the same way (Nobunaga N4).
unexported="$work/unexported.yml"
sed 's/^          export SERVICE_PATH="\$service_path"$/          SERVICE_PATH="$service_path"/' "$template" > "$unexported"
if cmp -s "$unexported" "$template"; then
  fail "appdata step [unexported mutant]: the template carries no 'export SERVICE_PATH=\"\$service_path\"' line to mutate"
else
  step="$work/appdata-step-unexported.sh"
  { cat "$work/where-stub.sh"; step_body "$unexported"; } > "$step"
  out="$(USERPROFILE='C:\Users\x' RUNNER_TEMP="$work/runner-temp" STUB_RECORDED="$stub_recorded" STUB_PATH='C:\Windows\system32\gh.exe' TOOLS=gh bash "$step" 2>&1)"
  code=$?
  first="$(printf '%s\n' "$out" | head -n 1)"
  if [ "$code" -eq 1 ] && [ "$first" = "gh: not on the service PATH" ]; then
    pass "appdata step [unexported mutant]: a step that does not export SERVICE_PATH is answered as where.exe would -- exit 1, 'gh: not on the service PATH'"
  else
    fail "appdata step [unexported mutant]: exit $code '$first', not exit 1 'gh: not on the service PATH' -- the stub reads a shell variable the real where.exe cannot see"
  fi
fi

# 2c. The remedy text names no install path (Copilot on zheref/nen#320): Git for Windows puts git.exe and
# bash.exe in subdirectories of C:\Program Files\Git, and GitHub CLI does not install under
# C:\Program Files\gh, so telling the maintainer to put C:\Program Files\<tool> on the PATH can leave the
# preflight failing. No ::error:: line may carry a tool-templated path segment, and every per-user remedy
# line -- the 127 one and the Windows resolution one -- still names the tool and the MACHINE PATH.
templated_path='[\\/]+(\$\{?tool\b|<tool>)'
for src in template render-windows-x64 render-macos-arm64 render-windows-x64-desktop; do
  case "$src" in
    template) from="$template" ;;
    *) from="$work/${src#render-}.yml" ;;
  esac
  [ -f "$from" ] || { fail "remedy ($src): no file to read at $from"; continue; }
  errors="$(grep -F '::error::' "$from")"
  bad_lines="$(printf '%s\n' "$errors" | grep -E "$templated_path")"
  if [ -n "$bad_lines" ]; then
    fail "remedy ($src): an ::error:: line names a tool-templated install path: $(printf '%s\n' "$bad_lines" | sed 's/^[[:space:]]*//' | tr '\n' ' ')"
  else
    pass "remedy ($src): no ::error:: line names a tool-templated install path"
  fi
  # Copilot on zheref/hatsu#179: a machine-wide tool may live outside Program Files, so no remedy names
  # an install location at all.
  bad_lines="$(printf '%s\n' "$errors" | grep -F 'Program Files')"
  if [ -n "$bad_lines" ]; then
    fail "remedy ($src): an ::error:: line names an install location (Program Files): $(printf '%s\n' "$bad_lines" | sed 's/^[[:space:]]*//' | tr '\n' ' ')"
  else
    pass "remedy ($src): no ::error:: line names an install location"
  fi
  per_user="$(printf '%s\n' "$errors" | grep -E '\$verdict|exit 127')"
  missing="$(printf '%s\n' "$per_user" | grep -v -e "'\$tool'" -e '^$' ; printf '%s\n' "$per_user" | grep -v -e 'MACHINE PATH' -e '^$')"
  if [ -z "$per_user" ]; then
    fail "remedy ($src): no per-user ::error:: line found (the 127 and the Windows resolution remedies)"
  elif [ -n "$missing" ]; then
    fail "remedy ($src): a per-user ::error:: line does not name both the tool and the MACHINE PATH: $(printf '%s\n' "$missing" | sed 's/^[[:space:]]*//' | sort -u | tr '\n' ' ')"
  else
    pass "remedy ($src): every per-user ::error:: line names the tool and the MACHINE PATH ($(printf '%s\n' "$per_user" | wc -l | tr -d ' ') line(s))"
  fi
done

# 2e. The interactive (desktop) pool (zheref/hatsu#206; nen 0.19, zheref/nen#333). The session probe runs
# only for an interactive Windows pool: its `if:` is exactly the template's, and on every rendering a
# constant, so a service pool never runs it. MODE reaches the toolchain and Windows steps.
probe_if="        if: runner.os == 'Windows' && '@@MODE@@' == 'interactive'"
probe_name='      - name: Desktop session present (interactive Windows pool)'
# probe_if_of <file>: the `if:` line of the probe step, or nothing.
probe_if_of() {
  awk -v name="$probe_name" '$0 == name { s = 1; next } s && /^      - / { exit } s && /^        if: / { print; exit }' "$1"
}
got="$(probe_if_of "$template")"
if [ "$got" = "$probe_if" ]; then
  pass "desktop (template): the session probe is gated exactly '${probe_if#        if: }'"
else
  fail "desktop (template): the session probe's if: is [$got], not exactly [${probe_if#        if: }]"
fi
for pair in "windows-x64|service" "macos-arm64|interactive" "windows-x64-desktop|interactive"; do
  pool="${pair%%|*}" mode="${pair#*|}"
  want="        if: runner.os == 'Windows' && '$mode' == 'interactive'"
  got="$(probe_if_of "$work/$pool.yml")"
  if [ "$got" = "$want" ]; then
    pass "desktop (render $pool): the probe's condition renders as the constant '$mode' == 'interactive'"
  else
    fail "desktop (render $pool): the probe's if: is [$got], not [${want#        if: }]"
  fi
done
got="$(grep -c "^          MODE: 'interactive'\$" "$work/windows-x64-desktop.yml")"
if [ "$got" = 2 ]; then
  pass "desktop (render windows-x64-desktop): MODE 'interactive' reaches the toolchain and the Windows steps"
else
  fail "desktop (render windows-x64-desktop): MODE 'interactive' appears $got time(s), not on exactly the toolchain and Windows steps"
fi
got="$(grep -c "^          MODE: 'service'\$" "$work/windows-x64.yml")"
if [ "$got" = 2 ]; then
  pass "desktop (render windows-x64): a service pool renders MODE 'service' on the same two steps"
else
  fail "desktop (render windows-x64): MODE 'service' appears $got time(s), not exactly 2"
fi
# The probe, lifted and run with powershell.exe stubbed to print a session id (CRLF, as Windows does).
probe_body() {
  awk -v name="$probe_name" '
    $0 == name { s = 1; next }
    s && /^      - / { exit }
    s && /^        run: \|/ { r = 1; next }
    r && /^        [^ ]/ { exit }
    r { sub(/^          /, ""); print }
  ' "$1"
}
for src in template rendering; do
  from="$template"; [ "$src" = rendering ] && from="$work/windows-x64-desktop.yml"
  step="$work/probe-$src.sh"
  { printf '%s\n' 'powershell.exe() { [ -n "${STUB_SESSION:-}" ] && printf '"'"'%s\r\n'"'"' "$STUB_SESSION"; return "${STUB_PS_RC:-0}"; }'; probe_body "$from"; } > "$step"
  grep -q 'SessionId' "$step" || { fail "desktop probe ($src): the session probe step was not found"; continue; }
  # <session id printed, '' = none>|<powershell exit>|<want exit>|<want first line>
  for probe in '2|0|0|session id: 2' '0|0|1|session id: 0' '|0|1|session id: unknown' '|1|1|session id: unknown'; do
    sess="${probe%%|*}" rest="${probe#*|}"
    ps_rc="${rest%%|*}" rest="${rest#*|}"
    want_code="${rest%%|*}" want="${rest#*|}"
    out="$(USERNAME=fixture-account STUB_SESSION="$sess" STUB_PS_RC="$ps_rc" bash "$step" 2>&1)"
    code=$?
    first="$(printf '%s\n' "$out" | head -n 1)"
    case "$out" in *fixture-account*) printed=yes ;; *) printed=no ;; esac
    named=yes
    if [ "$want_code" = 1 ]; then case "$out" in *'::error::'*'session'*'sign its account in'*) ;; *) named=no ;; esac; fi
    if [ "$code" = "$want_code" ] && [ "$first" = "$want" ] && [ "$printed" = no ] && [ "$named" = yes ]; then
      pass "desktop probe ($src): session '${sess:-none}' (powershell exit $ps_rc) -> exit $code, '$want', no account printed"
    else
      fail "desktop probe ($src): session '${sess:-none}' (powershell exit $ps_rc) -> exit $code '$first' (account printed: $printed, remedy named: $named), not exit $want_code '$want'"
    fi
  done
done
# The Windows resolution step, lifted from the desktop rendering and run with MODE=interactive: a per-user
# match is a ::warning:: and passes; not found and a refused exec still fail, naming the sign-in.
step="$work/appdata-step-desktop.sh"
{ cat "$work/where-stub.sh"; step_body "$work/windows-x64-desktop.yml"; } > "$step"
# <service PATH where.exe lines; MW = the stub executable>|<the stub executable's exit>|<exit>|<first line>|<a line the output must carry>
for probe in "C:\\Users\\x\\AppData\\Local\\Programs\\gh\\gh.exe|0|0|gh: per-user (AppData)|::warning::'gh' is per-user (AppData)" \
             "C:\\Users\\x\\scoop\\shims\\gh.exe|0|0|gh: per-user (profile)|::warning::'gh' is per-user (profile)" \
             "MW|0|0|gh: machine-wide|gh: machine-wide" \
             "|0|1|gh: not on the service PATH|sign the runner's account out and back in" \
             "MW|126|1|gh: machine-wide, refused on exec (exit 126)|sign the runner's account out and back in"; do
  path="${probe%%|*}" rest="${probe#*|}"
  exec_rc="${rest%%|*}" rest="${rest#*|}"
  want_code="${rest%%|*}" rest="${rest#*|}"
  want="${rest%%|*}" carry="${rest#*|}"
  path="${path//MW/$mw_gh}"
  out="$(MODE=interactive USERPROFILE='C:\Users\x' RUNNER_TEMP="$work/runner-temp" STUB_RECORDED="$stub_recorded" STUB_PATH="$path" STUB_EXEC_RC="$exec_rc" TOOLS=gh bash "$step" 2>&1)"
  code=$?
  first="$(printf '%s\n' "$out" | head -n 1)"
  case "$out" in *"$carry"*) carried=yes ;; *) carried=no ;; esac
  case "$out" in *'Users\x'*|*'Users/x'*|*'svc\bin'*|*"$work"*) printed=yes ;; *) printed=no ;; esac
  if [ "$code" = "$want_code" ] && [ "$first" = "$want" ] && [ "$carried" = yes ] && [ "$printed" = no ]; then
    pass "desktop windows step [MODE=interactive]: service [${path//$mw_gh/MW}], exec rc $exec_rc -> exit $code, '$want', carries \"$carry\", no path printed"
  else
    fail "desktop windows step [MODE=interactive]: service [${path//$mw_gh/MW}], exec rc $exec_rc -> exit $code '$first' (carries: $carried, path printed: $printed), not exit $want_code '$want' carrying \"$carry\""
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

# 4b. Negative: a push that admits a tag ref is refused (zheref/hatsu#198 item 1) -- `paths:` alone, the
# shape before #198 (GitHub evaluates no paths filter on a tag push, so every tag woke the pool: nen run
# 36801489069 on the v0.18.2 tag), and a `tags:` filter beside the branches one. nen renders both at
# exit 0; this guard refuses the copy and its rendering on the push-filters conjunct.
for shape in paths-only tags-added; do
  tagged="$work/$shape.yml"
  case "$shape" in
    paths-only) awk '/^    branches:$/ { skip = 1; next } skip && /^      - / { next } { skip = 0; print }' "$template" > "$tagged" ;;
    tags-added) awk '/^    paths:$/ { print "    tags:"; print "      - '"'"'v*'"'"'" } { print }' "$template" > "$tagged" ;;
  esac
  for target in template rendering; do
    file="$tagged"
    expect_slug='@@REPO_SLUG@@'
    is_rendered=no
    if [ "$target" = rendering ]; then
      render "$tagged" windows-x64 "$work/$shape-rendered.yml"
      [ "$render_code" -eq 0 ] || { fail "negative ($shape): nen refused the copy (exit $render_code), so it is not the case this guard exists for: $render_out"; continue; }
      file="$work/$shape-rendered.yml"
      expect_slug="$slug"
      is_rendered=yes
    fi
    before=$failures
    neg="$(check "tag $shape $target" "$file" "$expect_slug" '[self-hosted, Windows, X64]' '.github/workflows/runner-preflight-windows-x64.yml' "$is_rendered")"
    failures=$before
    case "$neg" in
      *"FAIL: tag $shape $target: push's filters are"*) pass "negative ($shape, $target): a push admitting a tag ref is refused" ;;
      *) fail "negative ($shape, $target): a push admitting a tag ref was not refused: $neg" ;;
    esac
  done
done

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
