#!/usr/bin/env bash
# Focused, declared verification for scripts/port_rule_reserve.sh (hatsu:bankai-rule § 3).
# Requires Bash, git and mktemp. No network: `gh` is a stub this fixture writes onto PATH.
# Invoked only through `nen shu test --lane port-rule-guard --repo <hatsu>`.
#
# THE TWO-BRANCH CASE (zheref/hatsu#355 criterion 7): one tip carrying PT-1..PT-3; branch A adds
# PT-4 and is "open as a PR" through the stub; branch B reserves next and must get PT-5, never PT-4.
# Also: a pair file absent at the tip reserves PT-1; an unreadable PR diff is exit 1, never clean;
# an unknown argument, a bad prefix and a non-repository are exit 2.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$repo_root/scripts/port_rule_reserve.sh"
root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-port-rule-guard.XXXXXX")"
trap 'rm -rf "$root"' EXIT
pass=0; total=0
check() { total=$((total+1)); if eval "$2"; then pass=$((pass+1)); echo "  ok    $1"; else echo "  FAIL  $1"; fi; }
g() { # git with a fixture identity, no global options on the command line
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.com GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.com git "$@"
}

# an "origin" with the tip, cloned as the authoring clone
origin="$root/origin"; clone="$root/clone"
g init -q -b main "$origin"
mkdir -p "$origin/handbooks/ports"
cat > "$origin/handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md" <<'MD'
<!-- pair: swiftui-tca-uzf-v2 -> compose-uzf-v2 · prefix: PT · next: 4 -->
| id | source | target | handling | rationale | date | supersedes |
|---|---|---|---|---|---|---|
| PT-1 | SW-3 | KT-2 | mirror | same shape | 2026-10-20 | |
| PT-2 | TCA Effect.run | Hilt repository call | map | effects become injected calls | 2026-10-20 | |
| PT-3 | SwiftUI .sheet | ModalBottomSheet | map | the idiom | 2026-10-20 | |
MD
g -C "$origin" add -A >/dev/null
g -C "$origin" commit -qm tip
g clone -q "$origin" "$clone"

# branch A: adds PT-4, served by the stub as open PR #7
g -C "$clone" switch -q -c a
printf '| PT-4 | SW-9 | none | drop with note | no twin | 2026-10-20 | |\n' >> "$clone/handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md"
g -C "$clone" commit -qam "A adds PT-4"
diff_a="$(g -C "$clone" diff main..a)"
g -C "$clone" switch -q main

# the gh stub: pr list -> one open PR (two with STUB_TWO); pr diff 7 -> branch A's diff; pr diff 9 -> unreadable
stub="$root/bin"; mkdir -p "$stub"
printf '%s\n' "$diff_a" > "$root/diff7.txt"
cat > "$stub/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "pr list") if [ -n "${STUB_TWO:-}" ]; then printf '7 a\n9 c\n'; else printf '7 a\n'; fi ;;
  "pr diff") if [ "$3" = 7 ]; then cat "$STUB_DIFF7"; else exit 1; fi ;;
  *) exit 2 ;;
esac
SH
chmod +x "$stub/gh"
export STUB_DIFF7="$root/diff7.txt"
export PATH="$stub:$PATH"

pair=handbooks/ports/swiftui-tca-uzf-v2--compose-uzf-v2.md
# branch B reserves
g -C "$clone" switch -q -c b
set +e
out="$(bash "$guard" --clone "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"; rc=$?
set -e
check "branch B reserves PT-5 past branch A's open PT-4 (exit $rc)" '[ "$rc" = 0 ] && printf "%s" "$out" | grep -q "^next: PT-5$"'
check "the tip's three and PR #7's one are all seen" '[ "$(printf "%s\n" "$out" | grep -c "seen:")" = 4 ] && printf "%s" "$out" | grep -q "PT-4 PR #7 (a)"'
outj="$(bash "$guard" --clone "$clone" --target acme/widget --pair-file "$pair" --prefix PT --json)"
check "--json carries next and number" 'printf "%s" "$outj" | grep -q "\"next\":\"PT-5\",\"number\":5"'
g -C "$clone" switch -q a
outa="$(bash "$guard" --clone "$clone" --target acme/widget --pair-file "$pair" --prefix PT)"
check "from branch A the same answer, PT-5: its own PT-4 is the open PR's, the tip is main" 'printf "%s" "$outa" | grep -q "^next: PT-5$"'
g -C "$clone" switch -q main
set +e
outn="$(bash "$guard" --clone "$clone" --target acme/widget --pair-file handbooks/ports/react-uzf-v1--compose-uzf-v2.md --prefix PT)"; rcn=$?
STUB_TWO=1 bash "$guard" --clone "$clone" --target acme/widget --pair-file "$pair" --prefix PT >/dev/null 2>&1; rcu=$?
bash "$guard" --clone "$clone" --target acme/widget --pair-file "$pair" --prefix 'P T' >/dev/null 2>&1; rcp=$?
bash "$guard" --clone "$root/nowhere" --target acme/widget --pair-file "$pair" --prefix PT >/dev/null 2>&1; rcc=$?
bash "$guard" --bogus >/dev/null 2>&1; rcb=$?
set -e
check "a pair file absent at the tip and in every PR reserves PT-1 (exit $rcn)" '[ "$rcn" = 0 ] && printf "%s" "$outn" | grep -q "^next: PT-1$"'
check "an unreadable open PR is exit 1, never clean" '[ "$rcu" = 1 ]'
check "a prefix with a space is usage" '[ "$rcp" = 2 ]'
check "a clone that is not a repository is exit 2" '[ "$rcc" = 2 ]'
check "an unknown argument is exit 2" '[ "$rcb" = 2 ]'

echo "port-rule-guard: $pass/$total"
[ "$pass" = "$total" ]
