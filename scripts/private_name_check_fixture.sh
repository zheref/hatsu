#!/usr/bin/env bash
# private_name_check_fixture.sh — the redaction-guard lane (zheref/hatsu#149).
#
# Hermetic and offline: the private list comes from --names-file or from a stub `gh` on a
# throwaway PATH, never from GitHub, and every private name below is invented (checked against the
# live list: none of them is a real private repository). Proves that a bare name, an owner/name slug
# and a case variant are each refused (exit 1) without the name ever being printed -- in a hit, a
# path, a label or an error; that `_` bounds a word (markdown emphasis is a hit) while a longer
# hyphenated word passes; that a name spelt through an escape, an entity, URL encoding, a tag, an
# invisible character, a fullwidth dash, intraword emphasis, a code span or an HTML comment is still a
# hit; that the predecessor marker passes only by its exact line shape and only for the name its
# source names, never for the same name spelt again on its line; that a path or label naming a
# repository only once normalised is withheld; that the target's visibility, the ignore file (an
# empty or comment-only one ignores nothing; one that ignores every name is a refusal), --tree
# (contents, paths, symlink targets, UTF-16 with a BOM, counted skips), stdin and --resolve behave as
# the header says; and that every wiring fault (gh missing or failing, a list that may be truncated
# or reads empty, an unreadable file, stdin twice, a bad argument, a perl that cannot load its
# modules) is exit 2, never a pass.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
guard="$here/private_name_check.sh"
work="$(mktemp -d)" || exit 2
trap 'rm -rf "$work"' EXIT

pass=0
fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$*"; }

# Invented private names. `zz-secret` and `Qux.Lab` carry the characters a name may hold; `Plinth`
# stands for a repository called after an ordinary word; `orchard-x` is owned by someone else.
names="$work/names"
cat > "$names" <<'EOF'
# a comment, then the list
acme/zz-secret
Qux.Lab

acme/Plinth
EOF
# The predecessor marker's source, as limbo's own line carries it.
msrc="$work/limbo.md"
printf '%s\n' '4. **The predecessor marker** — `head -1` against `<!-- GENERATED from zz-secret@`; nen knows' > "$msrc"

# Run the guard; capture stdout+stderr and the exit code. HOME is a throwaway so no real ignore file
# is ever read.
run() {
  out="$(HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" "$guard" "$@" 2>&1)"
  rc=$?
}
# expect <rc> <case> <args...>: also asserts no private name ever reaches the output.
expect() {
  local want="$1" name="$2"; shift 2
  run "$@"
  if [ "$rc" -ne "$want" ]; then bad "$name: exit $rc, wanted $want -- $out"; return; fi
  if printf '%s' "$out" | grep -qiE 'zz-secret|qux\.lab|orchard-x|plinth'; then bad "$name: a private name was printed -- $out"; return; fi
  ok
}
text() { printf '%s\n' "$2" > "$work/$1"; }
has() { printf '%s' "$out" | grep -q -- "$1" && ok || bad "$2 -- $out"; }
hasnt() { printf '%s' "$out" | grep -q -- "$1" && bad "$2 -- $out" || ok; }

# --- refused: the three forms the issue names -------------------------------------------------
text bare.md 'We built it in zz-secret last week.'
expect 1 "bare name" --names-file "$names" "$work/bare.md"
hasnt '#[0-9][0-9]* of' "a hit line carries no list size"
text slug.md 'See https://github.com/acme/zz-secret/issues/4 for the transcript.'
expect 1 "owner/name slug" --names-file "$names" "$work/slug.md"
text case.md 'ZZ-Secret and Zz-SeCrEt are the same repository.'
expect 1 "case variant" --names-file "$names" "$work/case.md"
[ "$(printf '%s\n' "$out" | grep -c 'private repository #')" -eq 2 ] && ok || bad "case variant: wanted two hits -- $out"
text dotted.md 'It lives in qux.lab, cloned as git@github.com:acme/zz-secret.git.'
expect 1 "dotted name and .git suffix" --names-file "$names" "$work/dotted.md"
[ "$(printf '%s\n' "$out" | grep -c 'private repository #')" -eq 2 ] && ok || bad "dotted: wanted two hits -- $out"
text period.md 'The last word is zz-secret.'
expect 1 "trailing sentence period" --names-file "$names" "$work/period.md"
run --names-file "$names" "$work/bare.md"
has "bare.md:1: private repository #" "hit names file and line"

# --- `_` bounds a word: emphasis and underscore joins are hits ------------------------------------
text em1.md 'italic _zz-secret_ here'
expect 1 "markdown italic" --names-file "$names" "$work/em1.md"
text em2.md 'bold __zz-secret__ here'
expect 1 "markdown bold" --names-file "$names" "$work/em2.md"
text em3.md 'joined my_zz-secret here'
expect 1 "underscore join" --names-file "$names" "$work/em3.md"

# --- spelt through markup, encoding or invisible characters -------------------------------------
text n1.md 'escaped zz\-secret here'
expect 1 "backslash escape" --names-file "$names" "$work/n1.md"
has 'spelt through' "a normalised hit says how it was found"
text n2.md 'entity zz&#45;secret here'
expect 1 "decimal HTML entity" --names-file "$names" "$work/n2.md"
text n2x.md 'entity zz&#x2d;secret here'
expect 1 "hex HTML entity" --names-file "$names" "$work/n2x.md"
text n2n.md 'entity zz&hyphen;secret here'
expect 1 "named HTML entity" --names-file "$names" "$work/n2n.md"
text n3.md 'see https://example.test/zz%2Dsecret'
expect 1 "URL encoding" --names-file "$names" "$work/n3.md"
printf 'zero-width zz\342\200\213-secret here\n' > "$work/n4.md"
expect 1 "zero-width space" --names-file "$names" "$work/n4.md"
printf 'fullwidth zz\357\274\215secret here\n' > "$work/n5.md"
expect 1 "fullwidth hyphen" --names-file "$names" "$work/n5.md"
printf 'fullwidth letters \357\275\232\357\275\232-secret here\n' > "$work/n5b.md"
expect 1 "fullwidth letters (NFKC)" --names-file "$names" "$work/n5b.md"
printf 'soft zz-sec\302\255ret here\n' > "$work/n6.md"
expect 1 "soft hyphen" --names-file "$names" "$work/n6.md"
text n7.md 'split zz<b></b>-secret here'
expect 1 "inline tag split" --names-file "$names" "$work/n7.md"
text n8.md 'escaped emphasis \_zz-secret\_ here'
expect 1 "markdown-escaped underscore" --names-file "$names" "$work/n8.md"
[ "$(printf '%s\n' "$out" | grep -c 'private repository #')" -eq 1 ] && ok || bad "one hit per name per line -- $out"
text m1.md 'bold tail zz-sec**ret** here'
expect 1 "intraword bold" --names-file "$names" "$work/m1.md"
text m2.md 'italic tail zz-sec*ret* here'
expect 1 "intraword italic" --names-file "$names" "$work/m2.md"
text m3.md 'comment split zz-<!-- -->secret here'
expect 1 "HTML comment split" --names-file "$names" "$work/m3.md"
text m4.md 'code split zz-`sec`ret here'
expect 1 "code-span split" --names-file "$names" "$work/m4.md"
text m5.md 'a comment hides nothing: <!-- zz&#45;secret -->'
expect 1 "an entity inside an HTML comment" --names-file "$names" "$work/m5.md"
text m6.md 'snake_case zz_secret and *zz* secret and `zz` -secret stay separate words'
expect 0 "intraword _ and emphasis between words are not joined" --names-file "$names" "$work/m6.md"

# --- passed: whole word, and the exempt marker ------------------------------------------------
text words.md 'zz-secret-tools, zz-secrets and quxolab are other words; QuxXLab too.'
expect 0 "longer words and a literal dot" --names-file "$names" "$work/words.md"
text marker.md '<!-- GENERATED from zz-secret@v0.11.2/rules sync-canon -->'
expect 0 "predecessor marker shape" --names-file "$names" --marker-source "$msrc" "$work/marker.md"
expect 1 "marker needs its source to name it" --names-file "$names" "$work/marker.md"
text marker2.md '<!-- GENERATED from zz-secret@v0.11.2 --> and zz-secret again'
expect 1 "marker does not exempt the rest of the line" --names-file "$names" --marker-source "$msrc" "$work/marker2.md"
text marker3.md '<!-- GENERATED from zz-secret without the at sign'
expect 1 "marker needs its @" --names-file "$names" --marker-source "$msrc" "$work/marker3.md"
text marker4.md '<!-- GENERATED from qux.lab@v1 -->'
expect 1 "marker shape exempts only the predecessor" --names-file "$names" --marker-source "$msrc" "$work/marker4.md"
text marker5.md 'quoted mid-line: `<!-- GENERATED from zz-secret@`'
expect 0 "the marker quoted mid-line, as limbo quotes it" --names-file "$names" --marker-source "$msrc" "$work/marker5.md"
text marker6.md 'GENERATED from zz-secret@v1 without the comment opener'
expect 1 "marker needs its comment opener" --names-file "$names" --marker-source "$msrc" "$work/marker6.md"
text marker7.md '<!-- GENERATED from zz-secret@v1 --> and zz&#x2d;secret again'
expect 1 "marker plus the name as an entity on its line" --names-file "$names" --marker-source "$msrc" "$work/marker7.md"
printf '<!-- GENERATED from zz-secret@v1 --> and zz\342\200\213-secret again\n' > "$work/marker8.md"
expect 1 "marker plus the name through a zero-width space" --names-file "$names" --marker-source "$msrc" "$work/marker8.md"
text marker9.md '<!-- GENERATED from zz-secret@v1 --> and zz-sec**ret** again'
expect 1 "marker plus the name through emphasis" --names-file "$names" --marker-source "$msrc" "$work/marker9.md"
text clean.md 'Nothing private here: zheref/nen and zheref/hatsu are public.'
expect 0 "clean text" --names-file "$names" "$work/clean.md"
hasnt 'checked against' "the list size stays out of the ok line"
expect 0 "--verbose names the list size" --names-file "$names" --verbose "$work/clean.md"
has 'checked against 3' "--verbose ok line"

# --- stdin, labels and paths never print a name -------------------------------------------------
out="$(printf 'body naming zz-secret\n' | HOME="$work/home" "$guard" --names-file "$names" --label issue-body - 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^issue-body:1:' && ok || bad "stdin with --label: $rc $out"
out="$(printf 'body naming zz-secret\n' | HOME="$work/home" "$guard" --names-file "$names" --label 'draft for zz-secret' - 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^draft for <private #' && ! printf '%s' "$out" | grep -qi 'zz-secret' && ok || bad "a label naming a repository is redacted: $rc $out"
out="$(printf 'body naming zz-secret\n' | HOME="$work/home" "$guard" --names-file "$names" --label 'draft %7Az-secret' - 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^<label withheld: private #' && ! printf '%s' "$out" | grep -qi '%7Az-secret\|zz-secret' && ok || bad "a label naming a repository once normalised is withheld: $rc $out"
out="$(printf 'clean body\n' | HOME="$work/home" "$guard" --names-file "$names" - 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok || bad "clean stdin: $rc $out"
out="$(printf 'x\n' | HOME="$work/home" "$guard" --names-file "$names" - - 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ok || bad "stdin twice: $rc $out"
out="$(printf 'zz-secret\n' | HOME="$work/home" "$guard" --names-file "$names" - -- - 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ok || bad "stdin twice through --: $rc $out"
mkdir -p "$work/zz-secret" && printf 'clean\n' > "$work/zz-secret/f.md" && chmod 000 "$work/zz-secret/f.md"
if [ ! -r "$work/zz-secret/f.md" ]; then
  expect 2 "unreadable file, its path redacted" --names-file "$names" "$work/zz-secret/f.md"
else ok; fi
chmod 644 "$work/zz-secret/f.md"

# --- the ignore file ---------------------------------------------------------------------------
: > "$work/ignore-empty"
expect 1 "an empty ignore file ignores nothing" --names-file "$names" --ignore-file "$work/ignore-empty" "$work/bare.md"
printf '# names too generic to police\n\n' > "$work/ignore-comments"
expect 1 "a comment-only ignore file ignores nothing" --names-file "$names" --ignore-file "$work/ignore-comments" "$work/bare.md"
hasnt 'allow-empty' "no --allow-empty claimed when it was not given"
mkdir -p "$work/home/.config/hatsu" && printf '# none yet\n' > "$work/home/.config/hatsu/redaction-ignore"
expect 1 "a comment-only DEFAULT ignore file ignores nothing" --names-file "$names" "$work/bare.md"
rm -f "$work/home/.config/hatsu/redaction-ignore"
printf 'zz-secret\nqux.lab\nplinth\n' > "$work/ignore-all"
expect 2 "an ignore file that ignores every name is a refusal" --names-file "$names" --ignore-file "$work/ignore-all" "$work/bare.md"
has 'every private name is ignored' "the refusal says why"
expect 0 "--allow-empty accepts every name ignored" --names-file "$names" --ignore-file "$work/ignore-all" --allow-empty "$work/bare.md"
text plinth.md 'It writes nen.stop.plinth/v0.2; Plinth the date.'
expect 1 "a word-like name is a finding by default" --names-file "$names" "$work/plinth.md"
printf 'plinth\n' > "$work/ignore"
expect 0 "ignore file drops it" --names-file "$names" --ignore-file "$work/ignore" "$work/plinth.md"
has '1 ignored' "ignored count reported on ok"
printf 'acme/plinth\n' > "$work/ignore-own"
expect 0 "owner/name ignores that repository" --names-file "$names" --ignore-file "$work/ignore-own" "$work/plinth.md"
printf 'other/plinth\n' > "$work/ignore-other"
expect 1 "another owner's entry ignores nothing here" --names-file "$names" --ignore-file "$work/ignore-other" "$work/plinth.md"
mkdir -p "$work/home/.config/hatsu" && printf 'PLINTH\n' > "$work/home/.config/hatsu/redaction-ignore"
expect 0 "default ignore file, case-insensitive" --names-file "$names" "$work/plinth.md"
rm -f "$work/home/.config/hatsu/redaction-ignore"
expect 1 "ignore file never hides another name" --names-file "$names" --ignore-file "$work/ignore" "$work/bare.md"
has '1 ignored' "ignored count reported on a refusal"
expect 2 "explicit ignore file missing" --names-file "$names" --ignore-file "$work/nope" "$work/bare.md"

# --- --tree ------------------------------------------------------------------------------------
repo="$work/repo"
mkdir -p "$repo/docs" && git -C "$repo" init -q
printf 'tracked line naming acme/zz-secret\n' > "$repo/docs/a.md"
printf 'clean\nsecond line naming zz-secret\n' > "$repo/docs/b.md"
printf 'zz-secret in an ignored file\n' > "$repo/scratch.log"
printf '*.log\n' > "$repo/.gitignore"
printf 'zz-secret\0binary\n' > "$repo/blob.bin"
printf 'untracked note naming qux.lab\n' > "$repo/docs/new.md"
git -C "$repo" add docs/a.md docs/b.md .gitignore blob.bin
expect 1 "tree: tracked and untracked" --names-file "$names" --tree "$repo"
printf '%s' "$out" | grep -q '^docs/a.md:1:' && printf '%s' "$out" | grep -q '^docs/new.md:1:' \
  && printf '%s' "$out" | grep -q '^docs/b.md:2:' \
  && ! printf '%s' "$out" | grep -q 'scratch.log\|blob.bin' && ok || bad "tree: wrong files -- $out"
expect 2 "tree: not a directory" --names-file "$names" --tree "$work/nope"
crepo="$work/clean-repo"
mkdir -p "$crepo" && git -C "$crepo" init -q
printf 'clean\n' > "$crepo/a.md"
printf 'zz-secret\0binary\n' > "$crepo/blob.bin"
git -C "$crepo" add a.md blob.bin
expect 0 "tree: a skipped binary is counted" --names-file "$names" --tree "$crepo"
has '1 skipped' "the skip is counted in the ok line"
prepo="$work/path-repo"
mkdir -p "$prepo/notes" && git -C "$prepo" init -q
printf 'clean body\n' > "$prepo/notes/zz-secret.md"
expect 1 "tree: a path names a repository" --names-file "$names" --tree "$prepo"
has '<private #' "the path is printed redacted"
erepo="$work/enc-repo"
mkdir -p "$erepo" && git -C "$erepo" init -q
printf 'clean body\n' > "$erepo/%7Az-secret.md"
expect 1 "tree: a path naming a repository once normalised" --names-file "$names" --tree "$erepo"
has '<path withheld: private #' "the encoded path is withheld"
hasnt '%7Az' "the encoded path never prints"
srepo="$work/link-repo"
mkdir -p "$srepo" && git -C "$srepo" init -q
ln -s ../zz-secret/README.md "$srepo/link.md"
expect 1 "tree: a symlink target names a repository" --names-file "$names" --tree "$srepo"
urepo="$work/utf16-repo"
mkdir -p "$urepo" && git -C "$urepo" init -q
printf '\377\376z\000z\000-\000s\000e\000c\000r\000e\000t\000\n\000' > "$urepo/u16.txt"
expect 1 "tree: a UTF-16 file with a BOM is decoded" --names-file "$names" --tree "$urepo"
vrepo="$work/utf16-nobom-repo"
mkdir -p "$vrepo" && git -C "$vrepo" init -q
printf 'z\000z\000-\000s\000e\000c\000r\000e\000t\000\n\000' > "$vrepo/u16.txt"
expect 0 "tree: UTF-16 without a BOM is binary, skipped" --names-file "$names" --tree "$vrepo"
has '1 skipped' "the BOM-less skip is counted"
nrepo="$work/nl-repo"
mkdir -p "$nrepo" && git -C "$nrepo" init -q
printf 'naming zz-secret\n' > "$nrepo/$(printf 'a\nb.md')"
expect 1 "tree: a path with a newline is still read" --names-file "$names" --tree "$nrepo"

# --- the live list, through a stub gh -----------------------------------------------------------
bin="$work/bin"
mkdir -p "$bin"
cat > "$bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "api user/repos?visibility=private&per_page=100 --paginate -q .[].full_name")
    [ -n "${STUB_FAIL:-}" ] && { echo "HTTP 401: Bad credentials" >&2; exit 1; }
    [ -n "${STUB_EMPTY:-}" ] && exit 0
    echo acme/zz-secret; echo acme/Qux.Lab; echo other-org/orchard-x ;;
  "repo list acme --visibility private --limit 1000"*)
    i=0; while [ $i -lt 1000 ]; do echo "acme/r$i"; i=$((i+1)); done ;;
  "repo list extra --visibility private --limit 1000"*) echo extra/plinth ;;
  "repo view acme/private-one --json visibility -q .visibility") echo PRIVATE ;;
  "repo view acme/public-one --json visibility -q .visibility") echo PUBLIC ;;
  "repo view acme/broken --json visibility -q .visibility") echo "not found" >&2; exit 1 ;;
  *) echo "stub gh: unexpected '$*'" >&2; exit 9 ;;
esac
EOF
chmod +x "$bin/gh"
sysbin="/usr/bin:/bin"
live() { PATH="$bin:$sysbin" expect "$@"; }
live 1 "live list: bare name" "$work/bare.md"
live 0 "live list: clean" "$work/clean.md"
has '2 owner(s)' "the ok line counts the owners checked"
text other.md 'the orchard-x repository belongs to another owner'
live 1 "live list: a private repository someone else owns" "$work/other.md"
live 1 "--owner adds an owner's list" --owner extra "$work/plinth.md"
STUB_FAIL=1 live 2 "live list: gh fails" "$work/bare.md"
STUB_EMPTY=1 live 2 "live list: reads empty" "$work/clean.md"
has 'read EMPTY' "an empty live list names the token's scope"
live 2 "--owner list possibly truncated" --owner acme "$work/clean.md"
live 0 "target private: skipped" --target acme/private-one "$work/bare.md"
has 'skipped' "skip stated"
live 1 "target public: checked" --target acme/public-one "$work/bare.md"
live 2 "target visibility unreadable" --target acme/broken "$work/bare.md"
live 2 "target not owner/name" --target broken "$work/bare.md"
mkdir -p "$work/nogh" && ln -sf "$(command -v perl)" "$work/nogh/perl"
for t in bash env sed sort grep awk tr head mktemp rm cat cp git dirname; do
  p="$(command -v "$t")" && ln -sf "$p" "$work/nogh/$t"
done
PATH="$work/nogh" expect 2 "gh missing" "$work/bare.md"

# --- --resolve and --help ----------------------------------------------------------------------
expect 2 "--resolve refuses a non-terminal" --names-file "$names" --resolve 1
expect 2 "--resolve needs a positive index" --names-file "$names" --resolve 0
run --help
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^# Exit codes' && ok || bad "--help prints the exit codes -- $rc"

# --- wiring -------------------------------------------------------------------------------------
PERL5OPT=-MNoSuchModuleX expect 2 "perl that cannot load its modules" --names-file "$names" "$work/clean.md"
has 'Encode and Unicode::Normalize' "the module refusal names the modules"
expect 2 "nothing to check" --names-file "$names"
expect 2 "unknown option" --names-file "$names" --bogus "$work/bare.md"
expect 2 "unreadable file" --names-file "$names" "$work/missing.md"
has 'could not be read' "an unreadable file is named as one, not as a perl failure"
expect 2 "unreadable names file" --names-file "$work/missing-names" "$work/bare.md"
: > "$work/empty-names"
expect 2 "empty names file" --names-file "$work/empty-names" "$work/bare.md"
printf '# only a comment\n\n' > "$work/blank-names"
expect 2 "names file with no names" --names-file "$work/blank-names" "$work/bare.md"
expect 0 "--allow-empty accepts it" --names-file "$work/empty-names" --allow-empty "$work/bare.md"

echo "redaction-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
