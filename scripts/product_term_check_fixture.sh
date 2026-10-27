#!/usr/bin/env bash
# product_term_check_fixture.sh — the product-term-guard lane (zheref/hatsu#354, wave 3: porting closes
# the loop).
#
# Hermetic and offline: the term list is a --terms-file this fixture writes, every term below is invented
# and stands for no product, and no network or gh is touched. Proves that a term in a table row and in
# prose is refused (exit 1) without the term ever being printed -- in a hit, a path, a label or an
# error; that the token reading joins camel case, `-`, `_`, `.`, `/`, a double space and a plain join
# (`OrderReview`, `order-review`, `orderreview` are one term) while a longer word, a plural, a reversed
# phrase and a prefixed word pass; that a term spelt through an escape, an entity, URL encoding, a tag, a
# format character, a combining mark, a default-ignorable code point, a fullwidth letter, intraword
# emphasis, a code span or an HTML comment is still a hit, while a confusable letter is pinned as the
# documented miss; that a path or label naming a term inside a camel-case word is withheld whole; that an object reference (`RA-IS-#12`, `RA#12`) in a ROW is a hit by shape, listed or not, even
# under --allow-empty, while the same shape in a header comment or prose is not a row, a `|`-led line
# inside a fence is judged as a row (a safe over-count) and `PT-5`, `SW-3`, `AC-001` carry no `#`; that CRLF and UTF-16-with-BOM files are read and a binary is skipped and
# counted; that a path or label naming a term is redacted or withheld; that the shipped pair-file
# templates read clean; and that every wiring fault (no default list -- missing-configuration -- an
# unreadable or empty list, a one-character term, stdin twice, a bad argument, --resolve off a terminal)
# is exit 2, never a pass.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
guard="$here/product_term_check.sh"
coverage_exec="${HATSU_SHELL_COVERAGE_EXEC:-}"
if [ -n "$coverage_exec" ]; then
  # Only the declared target traces; fixture assertions and child shells stay plain.
  set +x
  export HATSU_SHELL_COVERAGE_PS4="${PS4-}" HATSU_SHELL_COVERAGE_TRACE_FD="${BASH_XTRACEFD-}"
  export -n PS4 BASH_XTRACEFD SHELLOPTS
  [ "${HATSU_SHELL_COVERAGE_TARGET:-}" = "scripts/product_term_check.sh" ] && [ -x "$coverage_exec" ] || exit 2
fi
guard="${coverage_exec:-$guard}"
work="$(mktemp -d)" || exit 2
trap 'rm -rf "$work"' EXIT

pass=0
fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$*"; }

# Invented terms: a camel-cased screen, a one-word flow, a two-word tier, a product name, a business
# rule's verb. None names anything real.
terms="$work/terms"
cat > "$terms" <<'TXT'
# the maintainer's product terms (fixture copy)
OrderReview
checkout

Gold Tier
Plinth Pay
rebook
TXT
leak='order.?review|checkout|gold.?tier|plinth.?pay|rebook'

run() {
  out="$(HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" "$guard" "$@" 2>&1)"
  rc=$?
}
# expect <rc> <case> <args...>: also asserts no term ever reaches the output.
expect() {
  local want="$1" name="$2"; shift 2
  run "$@"
  if [ "$rc" -ne "$want" ]; then bad "$name: exit $rc, wanted $want -- $out"; return; fi
  if printf '%s' "$out" | grep -qiE "$leak"; then bad "$name: a term was printed -- $out"; return; fi
  ok
}
text() { printf '%s\n' "$2" > "$work/$1"; }
has() { printf '%s' "$out" | grep -q -- "$1" && ok || bad "$2 -- $out"; }
hasnt() { printf '%s' "$out" | grep -q -- "$1" && bad "$2 -- $out" || ok; }
hits() { [ "$(printf '%s\n' "$out" | grep -c ': product term #\|: object reference in a row')" -eq "$1" ] && ok || bad "$2: wanted $1 hit(s) -- $out"; }
row() { printf '| PT-%s | SW-1 | KT-1 | map | %s | restated | 2026-10-22 | |\n' "$1" "$2"; }

# --- refused: a term in a row, in every join the token reading folds -----------------------------
row 9 'the OrderReview screen keeps its rule' > "$work/camel.md"
expect 1 "camel-cased term in a row" --terms-file "$terms" "$work/camel.md"
has 'camel.md:1: product term #' "the hit names the file, the line and an index"
hasnt 'spelt through' "a raw hit does not claim a normalisation"
row 9 'the order-review effect' > "$work/hyphen.md"
expect 1 "hyphen join" --terms-file "$terms" "$work/hyphen.md"
row 9 'the order_review effect' > "$work/under.md"
expect 1 "underscore join" --terms-file "$terms" "$work/under.md"
row 9 'the order.review module' > "$work/dot.md"
expect 1 "dot join" --terms-file "$terms" "$work/dot.md"
row 9 'under order/review/' > "$work/slash.md"
expect 1 "slash join" --terms-file "$terms" "$work/slash.md"
row 9 'the orderreview flow' > "$work/joined.md"
expect 1 "plain join" --terms-file "$terms" "$work/joined.md"
row 9 'the order  review flow' > "$work/space2.md"
expect 1 "double space" --terms-file "$terms" "$work/space2.md"
row 9 'the ORDERREVIEW and Checkout flows' > "$work/case.md"
expect 1 "case variants" --terms-file "$terms" "$work/case.md"
hits 2 "two terms on one line are two hits"
row 9 'gold_tier and GoldTier and gold tier' > "$work/tier.md"
expect 1 "a two-word term through every join" --terms-file "$terms" "$work/tier.md"
hits 1 "one term three times on one line is one hit"
row 9 'rebook the slot' > "$work/verb.md"
expect 1 "a business-rule verb" --terms-file "$terms" "$work/verb.md"
text prose.md 'Prose naming the checkout flow is a hit too: the list applies to every line.'
expect 1 "a term in prose, not only in a row" --terms-file "$terms" "$work/prose.md"
text header.md '<!-- pair: a -> b · checkout -->'
expect 1 "a term in a header comment" --terms-file "$terms" "$work/header.md"

# --- passed: whole tokens, never substrings ---------------------------------------------------
row 9 'checkouts, precheckout, orders review, review order and goldtiers are other words' > "$work/words.md"
expect 0 "longer words, a plural, a prefix and a reversed phrase" --terms-file "$terms" "$work/words.md"
row 9 'a TCA reducer effect becomes an injected repository call' > "$work/clean.md"
expect 0 "clean row" --terms-file "$terms" "$work/clean.md"
hasnt 'term(s)' "the list size stays out of the ok line"
expect 0 "--verbose names the list size" --terms-file "$terms" --verbose "$work/clean.md"
has '5 term(s)' "--verbose ok line"

# --- spelt through markup, encoding or invisible characters -------------------------------------
row 9 'entity Order&#45;Review here' > "$work/n1.md"
expect 1 "decimal HTML entity" --terms-file "$terms" "$work/n1.md"
has 'spelt through' "a normalised hit says how it was found"
row 9 'entity Order&#x2d;Review here' > "$work/n2.md"
expect 1 "hex HTML entity" --terms-file "$terms" "$work/n2.md"
row 9 'entity order&hyphen;review here' > "$work/n3.md"
expect 1 "named HTML entity" --terms-file "$terms" "$work/n3.md"
row 9 'see https://example.test/order%2Dreview' > "$work/n4.md"
expect 1 "URL encoding" --terms-file "$terms" "$work/n4.md"
printf '| PT-9 | a | b | map | zero-width chec\342\200\213kout here | x | 2026-10-22 | |\n' > "$work/n5.md"
expect 1 "zero-width space inside a word" --terms-file "$terms" "$work/n5.md"
printf '| PT-9 | a | b | map | soft chec\302\255kout here | x | 2026-10-22 | |\n' > "$work/n6.md"
expect 1 "soft hyphen inside a word" --terms-file "$terms" "$work/n6.md"
printf '| PT-9 | a | b | map | fullwidth \357\275\203heckout here | x | 2026-10-22 | |\n' > "$work/n7.md"
expect 1 "fullwidth letter (NFKC)" --terms-file "$terms" "$work/n7.md"
row 9 'escaped chec\kout here' > "$work/n8.md"
expect 0 "a backslash before a letter is not an escape and splits the word" --terms-file "$terms" "$work/n8.md"
row 9 'escaped order\-review here' > "$work/n9.md"
expect 1 "backslash escape before punctuation" --terms-file "$terms" "$work/n9.md"
row 9 'tag split chec<b></b>kout here' > "$work/m1.md"
expect 1 "inline tag inside a word" --terms-file "$terms" "$work/m1.md"
row 9 'comment split chec<!-- -->kout here' > "$work/m2.md"
expect 1 "HTML comment inside a word" --terms-file "$terms" "$work/m2.md"
row 9 'code split chec`ko`ut here' > "$work/m3.md"
expect 1 "code-span split" --terms-file "$terms" "$work/m3.md"
row 9 'bold tail chec**kout** here' > "$work/m4.md"
expect 1 "intraword bold" --terms-file "$terms" "$work/m4.md"
row 9 'italic tail chec*kout* here' > "$work/m5.md"
expect 1 "intraword italic" --terms-file "$terms" "$work/m5.md"
row 9 'a comment hides nothing: <!-- chec&#107;out -->' > "$work/m6.md"
expect 1 "an entity inside an HTML comment" --terms-file "$terms" "$work/m6.md"

# --- the row rule: an object id in a table row, listed or not -----------------------------------
row 9 'ported from RA-IS-#12' > "$work/o1.md"
expect 1 "an issue object reference in a row" --terms-file "$terms" "$work/o1.md"
has 'object reference in a row' "the row rule names itself"
hasnt 'RA-IS\|#12' "the object id is never printed"
row 9 'see FI#7 and FA-PR-#42' > "$work/o2.md"
expect 1 "invocation-grammar and PR object ids in a row" --terms-file "$terms" "$work/o2.md"
hits 1 "two object ids on one row are one hit"
row 9 'ported from RA&#45;IS&#45;&#35;12' > "$work/o3.md"
expect 1 "an object id through entities in a row" --terms-file "$terms" "$work/o3.md"
has 'spelt through' "the normalised row hit says how it was found"
printf '   | PT-9 | a | b | map | RA#12 | x | 2026-10-22 | |\n' > "$work/o4.md"
expect 1 "an indented row is a row" --terms-file "$terms" "$work/o4.md"
: > "$work/empty"
row 9 'ported from RA#12' > "$work/o5.md"
expect 1 "--allow-empty with an empty list still runs the row rule" --terms-file "$work/empty" --allow-empty "$work/o5.md"
text o6.md '<!-- pair: a -> b · prefix: PT · numbering: global (zheref/hatsu docs/ROSTER.md § Rulings of 2026-10-21 (HA#355)) -->'
expect 0 "an object id in a header comment is not a row" --terms-file "$terms" "$work/o6.md"
text o7.md 'Prose citing HA#355 and RA-IS-#12 is not a row.'
expect 0 "an object id in prose is not a row" --terms-file "$terms" "$work/o7.md"
printf '```\n| RA#12 | inside a fence |\n```\n' > "$work/o8.md"
expect 1 "a row inside a fence is still a row (a safe over-count)" --terms-file "$terms" "$work/o8.md"
row 9 'supersedes PT-5; cites SW-3, UZF-26, AC-001, F001-AC-003 and SC-010' > "$work/o9.md"
expect 0 "rule ids and PT ids carry no # and are not object ids" --terms-file "$terms" "$work/o9.md"
row 9 'a #12 alone, ABCD#1 and a#1' > "$work/o10.md"
expect 0 "a bare number, four capitals and a lower-case code are not the shape" --terms-file "$terms" "$work/o10.md"

# --- files: CRLF, UTF-16, binary, unreadable -------------------------------------------------------
printf 'clean\r\n| PT-9 | a | b | map | checkout | x | 2026-10-22 | |\r\n' > "$work/crlf.md"
expect 1 "CRLF line endings" --terms-file "$terms" "$work/crlf.md"
has 'crlf.md:2:' "CRLF keeps its line numbers"
printf '\377\376c\000h\000e\000c\000k\000o\000u\000t\000\n\000' > "$work/u16.md"
expect 1 "a UTF-16 file with a BOM is decoded" --terms-file "$terms" "$work/u16.md"
printf 'checkout\0binary\n' > "$work/blob.bin"
expect 2 "a binary file (a NUL byte) is a refusal, never a skip (Phinks)" --terms-file "$terms" "$work/blob.bin"
has 'is not text' "the refusal names the input and why"
out="$(printf '| PT-1 | checkout \0 |\n' | HOME="$work/home" "$guard" --terms-file "$terms" - 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ! printf '%s' "$out" | grep -qiE "$leak" && ok || bad "a NUL byte on stdin is a refusal: $rc $out"
printf 'c\000h\000e\000c\000k\000o\000u\000t\000\n\000' > "$work/u16-nobom.md"
expect 2 "a UTF-16 file without a BOM is not text here: a refusal" --terms-file "$terms" "$work/u16-nobom.md"
mkdir -p "$work/checkout" && printf 'clean\n' > "$work/checkout/f.md" && chmod 000 "$work/checkout/f.md"
if [ ! -r "$work/checkout/f.md" ]; then
  expect 2 "unreadable file, its path redacted" --terms-file "$terms" "$work/checkout/f.md"
  has '<term #' "the unreadable path is printed redacted"
else ok; ok; fi
chmod 644 "$work/checkout/f.md"
expect 0 "a clean file under a path naming a term" --terms-file "$terms" "$work/checkout/f.md"
mkdir -p "$work/order%2Dreview" && printf 'checkout\n' > "$work/order%2Dreview/g.md"
expect 1 "a path naming a term once normalised is withheld" --terms-file "$terms" "$work/order%2Dreview/g.md"
has '<path withheld: term #' "the encoded path is withheld whole"

# --- stdin and labels never print a term ----------------------------------------------------------
out="$(printf 'the checkout flow\n' | HOME="$work/home" "$guard" --terms-file "$terms" --label rationale - 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^rationale:1:' && ! printf '%s' "$out" | grep -qiE "$leak" && ok || bad "stdin with --label: $rc $out"
out="$(printf 'the checkout flow\n' | HOME="$work/home" "$guard" --terms-file "$terms" --label 'draft for checkout' - 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^draft for <term #' && ! printf '%s' "$out" | grep -qiE "$leak" && ok || bad "a label naming a term is redacted: $rc $out"
out="$(printf 'the checkout flow\n' | HOME="$work/home" "$guard" --terms-file "$terms" --label 'draft chec%6Bout' - 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^<label withheld: term #' && ! printf '%s' "$out" | grep -qiE "$leak|%6B" && ok || bad "a label naming a term once normalised is withheld: $rc $out"
out="$(printf 'clean body\n' | HOME="$work/home" "$guard" --terms-file "$terms" - 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -qiE "$leak" && ok || bad "clean stdin: $rc $out"
out="$(printf 'x\n' | HOME="$work/home" "$guard" --terms-file "$terms" - - 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ! printf '%s' "$out" | grep -qiE "$leak" && ok || bad "stdin twice: $rc $out"
out="$(printf 'x\n' | HOME="$work/home" "$guard" --terms-file "$terms" - -- - 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ! printf '%s' "$out" | grep -qiE "$leak" && ok || bad "stdin twice through --: $rc $out"
# a term inside a camel-case word in a label: the separator-bounded rewrite cannot reach it, so the label
# is withheld whole (Feitan, hanten on 68eef8cf)
out="$(printf '| PT-1 | ported from RA#12 |\n' | HOME="$work/home" "$guard" --terms-file "$terms" --label 'draftCheckout' - 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^<label withheld: term #' && ! printf '%s' "$out" | grep -qiE "$leak" && ok || bad "a label naming a term inside a camel-case word is withheld: $rc $out"

# --- a term inside a camel-case word in a PATH is withheld whole, never printed (Feitan) ----------
for d in myOrderReview OrderReviewScreen checkoutFlow; do
  mkdir -p "$work/$d" && row 9 'ported from RA#12' > "$work/$d/x.md"
  expect 1 "a path naming a term inside a camel-case word ($d) is withheld" --terms-file "$terms" "$work/$d/x.md"
  has '<path withheld: term #' "the camel-case path is withheld whole"
done
printf 'clean\n' > "$work/myOrderReview/clean.md" && chmod 000 "$work/myOrderReview/clean.md"
if [ ! -r "$work/myOrderReview/clean.md" ]; then
  expect 2 "an unreadable file under a camel-case path naming a term" --terms-file "$terms" "$work/myOrderReview/clean.md"
  has '<path withheld: term #' "the unreadable camel-case path is withheld"
else ok; ok; fi
chmod 644 "$work/myOrderReview/clean.md"

# --- combining marks and default-ignorable code points fold; a confusable letter does not ---------
printf '| PT-9 | a | b | map | acute che\314\201ckout here | x | 2026-10-22 | |\n' > "$work/c1.md"
expect 1 "a combining acute inside a word (NFKD, Mn deleted)" --terms-file "$terms" "$work/c1.md"
printf '| PT-9 | a | b | map | selector chec\357\270\217kout here | x | 2026-10-22 | |\n' > "$work/c2.md"
expect 1 "a variation selector inside a word" --terms-file "$terms" "$work/c2.md"
printf '| PT-9 | a | b | map | joiner chec\315\217kout here | x | 2026-10-22 | |\n' > "$work/c3.md"
expect 1 "a combining grapheme joiner inside a word" --terms-file "$terms" "$work/c3.md"
printf '| PT-9 | a | b | map | filler chec\343\205\244kout here | x | 2026-10-22 | |\n' > "$work/c4.md"
expect 1 "a hangul filler inside a word" --terms-file "$terms" "$work/c4.md"
printf '| PT-9 | a | b | map | override chec\342\200\256kout here | x | 2026-10-22 | |\n' > "$work/c5.md"
expect 1 "a right-to-left override inside a word (Cf)" --terms-file "$terms" "$work/c5.md"
printf '| PT-9 | a | b | map | cyrillic ch\320\265ckout here | x | 2026-10-22 | |\n' > "$work/c6.md"
expect 0 "a confusable letter (Cyrillic е) is not folded: the documented miss, no confusables table" --terms-file "$terms" "$work/c6.md"

# --- a label holding a control character forges hit lines: refused (Phinks) -------------------------
out="$(printf '| PT-1 | checkout |\n' | HOME="$work/home" "$guard" --terms-file "$terms" --label "$(printf 'x\ny:1: forged')" - 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ! printf '%s' "$out" | grep -q 'forged:1:' && ok || bad "a label with a newline is refused: $rc $out"

# --- the token alphabet is ASCII on both sides: a term with diacritics folds, one in another script is refused
printf 'Caf\303\251\n' > "$work/accent"
printf '| PT-9 | a | b | map | the caf\303\251 flow | x | 2026-10-22 | |\n' > "$work/accent.md"
expect 1 "a term with a diacritic reads folded on both sides (Café, café)" --terms-file "$work/accent" "$work/accent.md"
row 9 'the caf flow' > "$work/caf.md"
expect 0 "the folded term is cafe, never caf" --terms-file "$work/accent" "$work/caf.md"
printf 'OrderReview\n\347\231\272\346\263\250\n' > "$work/cjk"
expect 2 "a term in another script leaves no ASCII letter and is refused by name" --terms-file "$work/cjk" "$work/clean.md"
has 'token alphabet' "the refusal names the alphabet"
hasnt 'flag everything' "a term that would never match is not said to flag everything"

# --- the list: the maintainer's, never a session's -------------------------------------------------
expect 2 "no default list is missing-configuration" "$work/clean.md"
has 'missing-configuration' "the refusal names the row"
has 'the maintainer writes it' "the refusal says who writes it"
mkdir -p "$work/home/.config/hatsu" && cp "$terms" "$work/home/.config/hatsu/product-terms"
expect 1 "the default list is read when present" "$work/camel.md"
expect 0 "the default list is read on a clean file too" "$work/clean.md"
has "the maintainer's list" "a default-list run says whose list it read"
rm -f "$work/home/.config/hatsu/product-terms"
ln -s "$work/nope" "$work/home/.config/hatsu/product-terms"
expect 2 "a dangling default-list link is a wiring fault, never absent" "$work/clean.md"
hasnt 'missing-configuration' "a dangling link is not the missing row"
rm -f "$work/home/.config/hatsu/product-terms"
expect 2 "an explicit list that does not exist" --terms-file "$work/nope" "$work/clean.md"
expect 2 "an empty list without --allow-empty" --terms-file "$work/empty" "$work/clean.md"
has 'holds no terms' "the refusal says why"
printf '# comments only\n\n' > "$work/comments"
expect 2 "a comment-only list without --allow-empty" --terms-file "$work/comments" "$work/clean.md"
expect 0 "--allow-empty accepts an empty list" --terms-file "$work/empty" --allow-empty "$work/clean.md"
printf 'OrderReview\nx\n' > "$work/short"
expect 2 "a one-character term is refused" --terms-file "$work/short" "$work/clean.md"
has 'would flag everything' "the refusal says why"
has 'entry 2 of the sorted' "the message names the --resolve index (1-based, sorted), not a file line"
printf 'OrderReview\n---\n' > "$work/punct"
expect 2 "a term of punctuation only is refused" --terms-file "$work/punct" "$work/clean.md"
printf 'OrderReview\norder review\norder-review\norderreview\n' > "$work/dupes"
expect 1 "four spellings of one term share one index" --terms-file "$work/dupes" --verbose "$work/camel.md"
hits 1 "one hit for the four spellings"
has 'product term #1 ' "the shared index is the first spelling's, stable across runs (Nobunaga)"
expect 1 "the same index on a second run" --terms-file "$work/dupes" "$work/camel.md"
has 'product term #1 ' "stable on the second run"
expect 0 "--verbose counts the folded list" --terms-file "$work/dupes" --verbose "$work/clean.md"
has '1 term(s)' "four spellings count once"
chmod 000 "$terms"
if [ ! -r "$terms" ]; then expect 2 "an unreadable list" --terms-file "$terms" "$work/clean.md"; else ok; fi
chmod 644 "$terms"
out="$(env -u HOME -u XDG_CONFIG_HOME "$guard" "$work/clean.md" 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'neither XDG_CONFIG_HOME nor HOME' && ok || bad "HOME and XDG_CONFIG_HOME unset is a wiring fault: $rc $out"
out="$(env -u HOME -u XDG_CONFIG_HOME "$guard" --terms-file "$terms" "$work/clean.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok || bad "an explicit list needs no HOME: $rc $out"

# --- arguments and --resolve ------------------------------------------------------------------------
expect 2 "no inputs" --terms-file "$terms"
expect 2 "unknown option" --terms-file "$terms" --tree "$work" "$work/clean.md"
expect 2 "--terms-file with no value" --terms-file
expect 2 "--resolve 0" --terms-file "$terms" --resolve 0
expect 2 "--resolve past the list" --terms-file "$terms" --resolve 99
expect 2 "--resolve off a terminal is refused" --terms-file "$terms" --resolve 1
has 'only to a terminal' "the refusal says why"
out="$("$guard" --help 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'Usage:' && ok || bad "--help prints the header: $rc"

# --- the shipped templates read clean --------------------------------------------------------------
tpl="$here/../templates/ports"
if [ -f "$tpl/pair.md" ] && [ -f "$tpl/INDEX.md" ]; then
  expect 0 "templates/ports/pair.md and INDEX.md read clean (the header's HA#355 is a comment, not a row)" --terms-file "$terms" "$tpl/pair.md" "$tpl/INDEX.md"
else bad "templates/ports/pair.md or INDEX.md is missing beside this fixture"; fi
sed -e 's/<from>/swiftui-tca-uzf-v2/g' -e 's/<to>/compose-uzf-v2/g' -e 's/<from-prefix>/SW/g' -e 's/<to-prefix>/KT/g' "$tpl/pair.md" > "$work/rendered.md"
row 1 'a TCA reducer effect becomes an injected repository call' >> "$work/rendered.md"
expect 0 "a rendered pair file with one technology-level row reads clean" --terms-file "$terms" "$work/rendered.md"
row 2 'the OrderReview sheet' >> "$work/rendered.md"
expect 1 "the same file with one product row is refused at that row" --terms-file "$terms" "$work/rendered.md"
has "rendered.md:$(wc -l < "$work/rendered.md" | tr -d ' '): product term #" "the hit is the last row"

echo "product-term-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
