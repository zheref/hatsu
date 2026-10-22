#!/usr/bin/env bash
# product_term_check.sh — refuse text that names a product term in a public pair file (zheref/hatsu#354,
# wave 3 of the SDD assessment: porting closes the loop).
#
# docs/config/ports.md § *Product-level divergence* and claude/skills/bankai-rule/SKILL.md § 1 forbid a
# product, screen, business-rule or object-id word in a pair file's `rationale` and `redraft`: a pair file
# (zheref/bankai-handbooks handbooks/ports/*.md) is public and technology-level, and the product words
# live in the private spec folder's `## Platform decisions`. Until now only the prose asked for it, and
# scripts/private_name_check.sh (frozen under BC-11) matches private REPOSITORY names only. This guard is
# the mechanical half: it compares text against the maintainer's own PRODUCT-TERM LIST, kept outside
# every public tree:
#
#   ${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/product-terms   (--terms-file <path> names another; a fixture's)
#
# One term per line, `#` comments, blanks ignored, ends trimmed. A term is a literal phrase -- a product
# name, a screen, a business rule's words, a tier or plan name -- and it is matched by TOKENS: the term
# and every line are both read lower-case with a camel-case boundary (`OrderReview` → `order review`)
# and every run of non-alphanumerics (space, `-`, `_`, `.`, `/`, `(`) as one separator, and the term's
# words may touch or be one separator apart, so `order review`, `Order-Review`, `order_review`,
# `OrderReview` and `orderreview` are one term, while `preorder review`, `orders review` and
# `checkouts` (for `checkout`) are other words: whole tokens, never substrings. A plural or an
# inflection is its own line. A line holding `%`, `&`, `<`, `\`, `*`, a backtick or a non-ASCII byte is
# also read normalised, twice, exactly as private_name_check.sh reads it -- %XX decoded, UTF-8 decoded,
# HTML entities decoded, inline tags and backslash escapes before punctuation dropped, NFKC applied,
# format characters deleted and every dash folded to `-`; then with HTML comments, `*` and backticks
# removed -- and a hit found only that way says so at its original line. Those transformations are
# the whole claim.
#
# The one rule that needs no list: an OBJECT ID in a table row. A line whose first non-blank character
# is `|` is a row of the equivalence or drift table (the only place a pair file carries a ruling), and
# `<CODE>-<IS|PR>-#<n>` or `<CODE>#<n>` there (`RA-IS-#12`, `FI#7`; two or three capitals) is a hit by
# shape, listed or not: a pair row never cites a product's issue or PR. The same shape in a header
# comment, in prose or in a fenced block is not a row and is not judged by this rule (the template's
# header cites a Hatsu ruling by object id); `PT-<n>`, `SW-{n}` and the other rule ids carry no `#`.
#
# The output NEVER prints a term: a hit is `<file>:<line>: product term #<k>`, an index into the list
# (sorted with LC_ALL=C, duplicates by token form dropped, first spelling kept); a path or --label that
# contains a term is printed with it replaced by `<term #k>`, and one that holds a term only once
# normalised is withheld whole. `--resolve <k>` prints entry k to a terminal only (stderr, refused when
# stderr is not a terminal), so an index never reaches a log as a term. The ok line carries the list's
# size only under --verbose.
#
# A list that cannot be read is a refusal, never a pass. NO DEFAULT LIST IS `missing-configuration`
# (exit 2): the guard cannot say a row is product-free with nothing to compare it to, and the file is
# the maintainer's -- written by hand, named in docs/PUBLIC-REDACTION.md § *How it is guarded* and
# docs/config/ports.md § *The product-term guard* -- NEVER by a session, never committed to a public
# tree (it would publish what it guards). An empty or comment-only list is exit 2 unless --allow-empty.
#
# Usage:
#   product_term_check.sh [--terms-file <path>] [--allow-empty] [--label <name>] [--verbose] [<file>|-]...
#   product_term_check.sh [--terms-file <path>] --resolve <k>
#
#   --terms-file   one term per line (`#` comments, blanks ignored), INSTEAD of the default list.
#   --allow-empty  an empty list is clean (exit 0) instead of a refusal; the object-id rule still runs.
#   --label        the name a stdin read is reported under (default `<stdin>`).
#   -              read stdin (once).
#
# Exit codes: 0 clean, 1 a product term or an object id in a row found, 2 wiring -- no list (missing-
# configuration), an unreadable list or file, a term that normalises to nothing or to one character,
# stdin given twice, a bad argument, --resolve off a terminal, perl missing or lacking Encode /
# Unicode::Normalize, or the scan failing in perl. A guard that cannot read its list never reads green.
#
# BC-11: this guard decides with a three-way exit, a verdict; like private_name_check.sh it is owed to a
# nen verb (zheref/nen#441 names the family) and is FROZEN to fixes once that verb lands.
set -u

die() { printf 'product_term_check: %s\n' "$*" >&2; exit 2; }

terms_file=""
terms_explicit=0
if [ -n "${XDG_CONFIG_HOME:-}" ]; then terms_file="$XDG_CONFIG_HOME/hatsu/product-terms"
elif [ -n "${HOME:-}" ]; then terms_file="$HOME/.config/hatsu/product-terms"
fi
allow_empty=0
label="<stdin>"
verbose=0
resolve=""
inputs=()
stdin_seen=0

while [ $# -gt 0 ]; do
  case "$1" in
    --terms-file) [ $# -ge 2 ] && [ -n "$2" ] || die "--terms-file needs a path"; terms_file="$2"; terms_explicit=1; shift 2 ;;
    --allow-empty) allow_empty=1; shift ;;
    --label) [ $# -ge 2 ] && [ -n "$2" ] || die "--label needs a name"; label="$2"; shift 2 ;;
    --verbose) verbose=1; shift ;;
    --resolve) [ $# -ge 2 ] && [ -n "$2" ] || die "--resolve needs an index"; resolve="$2"; shift 2 ;;
    --help|-h) awk 'NR > 1 && /^set -u$/ { exit } NR > 1 { print }' "$0"; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do inputs+=("$1"); shift; done ;;
    -) [ "$stdin_seen" -eq 0 ] || die "stdin ('-') given twice"; stdin_seen=1; inputs+=("-"); shift ;;
    -*) die "unknown option '$1'" ;;
    *) inputs+=("$1"); shift ;;
  esac
done
n_stdin=0
for f in "${inputs[@]+"${inputs[@]}"}"; do
  [ "$f" != "-" ] || n_stdin=$((n_stdin + 1))
done
[ "$n_stdin" -le 1 ] || die "stdin ('-') given twice"

command -v perl >/dev/null 2>&1 || die "perl is required and was not found"
perl -MEncode -MUnicode::Normalize -e1 >/dev/null 2>&1 \
  || die "perl cannot load Encode and Unicode::Normalize (core modules; a perl-base-only host lacks them)"
if [ -z "$resolve" ]; then
  [ ${#inputs[@]} -gt 0 ] || die "nothing to check: pass files or '-'"
fi

tmp="$(mktemp -d)" || die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

# --- the list: the maintainer's file, never a session's -----------------------------------------
[ -n "$terms_file" ] || die "neither XDG_CONFIG_HOME nor HOME is set, so there is no default product-term list; pass --terms-file <path>"
if [ ! -e "$terms_file" ] && [ ! -L "$terms_file" ] && [ "$terms_explicit" -eq 0 ]; then
  die "missing-configuration: no product-term list at $terms_file -- the maintainer writes it by hand (docs/config/ports.md section The product-term guard), one term per line; a session never does, and nothing is clean until it exists"
fi
[ -f "$terms_file" ] && [ -r "$terms_file" ] || die "cannot read the product-term list '$terms_file'"
list="$tmp/terms"
sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$terms_file" | LC_ALL=C sort -u > "$list" \
  || die "cannot read the product-term list '$terms_file'"
if ! grep -q . "$list"; then
  [ "$allow_empty" -eq 1 ] || die "the product-term list holds no terms; pass --allow-empty if that is meant (an empty list checks nothing)"
fi
if [ "$terms_explicit" -eq 1 ]; then source_desc="the --terms-file list"; else source_desc="the maintainer's list"; fi

# --- --resolve: one entry, to a terminal only ---------------------------------------------------
if [ -n "$resolve" ]; then
  case "$resolve" in *[!0-9]*|0) die "--resolve needs a positive index, got '$resolve'" ;; esac
  [ -t 2 ] || die "--resolve prints only to a terminal (stderr is not one), so a term never reaches a log"
  n_terms="$(grep -c . "$list")"
  [ "$resolve" -le "$n_terms" ] || die "--resolve $resolve: the list has $n_terms entries"
  printf '#%s: %s\n' "$resolve" "$(sed -n "${resolve}p" "$list")" >&2
  exit 0
fi

: > "$tmp/stdin"
[ "$n_stdin" -eq 0 ] || cat > "$tmp/stdin" || die "cannot read stdin"

# One perl pass; see the header for the token reading, the normalisation and the row rule.
PTC_TERMS="$list" PTC_LABEL="$label" PTC_STDIN="$tmp/stdin" PTC_SKIPPED="$tmp/skipped" PTC_COUNT="$tmp/count" perl -e '
  use strict; use warnings;
  use Encode qw(decode encode FB_DEFAULT);
  use Unicode::Normalize qw(NFKC);
  # The token reading: a camel-case boundary and every run of non-alphanumerics become one space.
  sub tokens {
    my $s = shift;
    $s =~ s/(?<=[a-z0-9])(?=[A-Z])/ /g;
    $s =~ s/(?<=[A-Z])(?=[A-Z][a-z])/ /g;
    $s = lc $s;
    $s =~ s/[^a-z0-9]+/ /g;
    $s =~ s/^ //; $s =~ s/ $//;
    return $s;
  }
  open(my $tf, "<", $ENV{PTC_TERMS}) or exit 3;
  my @raw = grep { length } map { chomp; $_ } <$tf>; close $tf;
  my (%idx, @pats, @names);
  for my $i (0 .. $#raw) {
    my $t = tokens(decode("UTF-8", $raw[$i], FB_DEFAULT));
    if (length($t) < 2) { print STDERR "product_term_check: entry $i of the list normalises to " . (length $t ? "one character" : "nothing") . " and would flag everything; remove or lengthen it\n"; exit 6 }
    next if exists $idx{$t};           # a second spelling of one term shares its index
    $idx{$t} = $i + 1;
    push @names, $t;
    my @w = split / /, $t;
    push @pats, join(" ?", map { quotemeta } @w);
  }
  my $n_terms = scalar @names;
  open(my $cf, ">", $ENV{PTC_COUNT}) or exit 3; print $cf "$n_terms\n"; close $cf;
  my $re = $n_terms ? do { my $alt = join "|", sort { length($b) <=> length($a) } @pats; qr/(?<![a-z0-9])($alt)(?![a-z0-9])/ } : undef;
  # The row rule: an object id in a table row, two or three capitals, optional -IS-/-PR-, then #<n>.
  my $oid = qr/(?<![A-Za-z0-9])[A-Z]{2,3}(?:-(?:IS|PR)-)?#[0-9]+(?![A-Za-z0-9])/;
  sub key_of { my $m = shift; (my $k = $m) =~ s/ //g; for my $n (keys %idx) { (my $kn = $n) =~ s/ //g; return $idx{$n} if $kn eq $k } return 0 }

  my %ent = (amp => "&", lt => "<", gt => ">", quot => "\"", apos => "\x27", nbsp => " ",
    hyphen => "-", dash => "-", minus => "-", ndash => "-", mdash => "-", lowbar => "_",
    UnderBar => "_", period => ".", sol => "/", bsol => "\\", colon => ":", commat => "@",
    num => "#", percnt => "%", shy => "", zwsp => "", zwj => "", zwnj => "", NewLine => " ");
  sub cp { my $c = shift; return ($c > 0x10FFFF || ($c >= 0xD800 && $c <= 0xDFFF)) ? "\x{FFFD}" : chr($c) }
  sub norm {
    my $s = shift;
    $s =~ s/%([0-9A-Fa-f]{2})/chr(hex $1)/ge;
    $s = decode("UTF-8", $s, FB_DEFAULT);
    for (1 .. 2) {
      $s =~ s/&#[xX]([0-9A-Fa-f]{1,6});/cp(hex $1)/ge;
      $s =~ s/&#([0-9]{1,7});/cp($1)/ge;
      $s =~ s/&([A-Za-z][A-Za-z0-9]{1,31});/exists $ent{$1} ? $ent{$1} : "&$1;"/ge;
    }
    $s =~ s{</?[A-Za-z][^<>]*>}{}g;
    $s =~ s/\\(?=[!-\/:-\@\[-`{-~])//g;
    $s = NFKC($s);
    $s =~ s/\p{Cf}//g;
    $s =~ s/\p{Pd}/-/g;
    return $s;
  }
  sub norm2 { my $s = shift; $s =~ s/<!--.*?-->//g; $s =~ s/[*`]//g; return $s }
  sub trig { return $_[0] =~ /[%&<\\*`]|[^\x00-\x7F]/ }
  # What a shown path or label may print: term matches replaced by their index; one that holds a term
  # only once normalised is withheld whole.
  sub redact {
    my $s = shift;
    return $s unless $re;
    my $t = tokens($s);
    my %hit; while ($t =~ /$re/g) { $hit{key_of($1)} = 1 }
    return $s unless %hit;
    # a plain path: rewrite each matching token run by its index
    for my $k (sort keys %hit) {
      my ($name) = grep { $idx{$_} == $k } keys %idx;
      my @w = split / /, $name;
      my $p = join("[^A-Za-z0-9]*", map { my $q = quotemeta $_; "(?i:$q)" } @w);
      $s =~ s/(?<![A-Za-z0-9])$p(?![A-Za-z0-9])/<term #$k>/g;
    }
    return $s;
  }
  sub safe {
    my ($s, $kind) = @_;
    my $r = redact($s);
    return $r unless $re && trig($r);
    my $m = norm($r);
    for my $v ($m, norm2($m)) { my $t = tokens($v); return "<$kind withheld: term #" . key_of($1) . ">" if $t =~ $re }
    return $r;
  }

  my ($hits, $bad, $skipped) = (0, 0, 0);
  sub hit_term { my ($shown, $n, $k, $how) = @_; printf "%s:%s: product term #%d%s -- restate it technology-level, or move the words to the spec folder (docs/config/ports.md section The product-term guard)\n", $shown, $n, $k, $how; $hits++ }
  sub hit_oid { my ($shown, $n, $how) = @_; printf "%s:%s: object id in a row%s -- a pair row never cites a product object (docs/config/ports.md section The product-term guard)\n", $shown, $n, $how; $hits++ }
  sub line {
    my ($l, $shown, $n) = @_;
    my %seen; my $oid_seen = 0;
    my $row = ($l =~ /^\s*\|/) ? 1 : 0;
    if ($re) { my $t = tokens($l); while ($t =~ /$re/g) { my $k = key_of($1); next if $seen{$k}; hit_term($shown, $n, $k, ""); $seen{$k} = 1 } }
    if ($row && $l =~ $oid) { hit_oid($shown, $n, ""); $oid_seen = 1 }
    return unless trig($l);
    my $m = norm($l);
    for my $v ($m, norm2($m)) {
      if ($re) { my $t = tokens($v); while ($t =~ /$re/g) { my $k = key_of($1); next if $seen{$k}; hit_term($shown, $n, $k, " (spelt through an escape, entity, encoding, markup or invisible character)"); $seen{$k} = 1 } }
      my $vrow = ($v =~ /^\s*\|/) ? 1 : 0;
      if (($row || $vrow) && !$oid_seen && $v =~ $oid) { hit_oid($shown, $n, " (spelt through an escape, entity, encoding, markup or invisible character)"); $oid_seen = 1 }
    }
  }
  sub text { my ($t, $shown) = @_; my $n = 0; for my $l (split /\n/, $t, -1) { $n++; $l =~ s/\r\z//; line($l, $shown, $n) } }
  sub scan {
    my ($path, $shown) = @_;
    my $fh;
    local $/ = "\n";
    unless (-f $path && open($fh, "<:raw", $path)) { print STDERR "product_term_check: cannot read $shown\n"; $bad = 1; return; }
    my $head = ""; read($fh, $head, 8192);
    if ($head =~ /\A(\xFF\xFE|\xFE\xFF)/) {
      local $/; seek($fh, 0, 0); my $all = <$fh>; close $fh;
      text(encode("UTF-8", decode("UTF-16", $all, FB_DEFAULT)), $shown);
      return;
    }
    if (index($head, "\0") >= 0) { close $fh; $skipped++; return; }
    seek($fh, 0, 0);
    while (my $l = <$fh>) { chomp $l; $l =~ s/\r\z//; line($l, $shown, $.) }
    close $fh;
  }
  my $ok = eval {
    for my $a (@ARGV) {
      if ($a eq "-") { scan($ENV{PTC_STDIN}, safe($ENV{PTC_LABEL}, "label")) } else { scan($a, safe($a, "path")) }
    }
    1 };
  unless ($ok) { print STDERR "product_term_check: perl: " . redact($@ // "died"); exit 5 }
  open(my $sk, ">", $ENV{PTC_SKIPPED}) or exit 3; print $sk "$skipped\n"; close $sk;
  exit 4 if $bad;
  exit($hits ? 1 : 0);
' -- "${inputs[@]+"${inputs[@]}"}" > "$tmp/out"
rc=$?
cat "$tmp/out"
skipped="$(cat "$tmp/skipped" 2>/dev/null || echo '?')"
n_terms="$(cat "$tmp/count" 2>/dev/null || echo '?')"
size=""
[ "$verbose" -eq 1 ] && size=" ($n_terms term(s))"
case "$rc" in
  0) echo "product_term_check: ok -- no product term and no object id in a row ($source_desc$size; $skipped skipped as binary or not a regular file)" ;;
  1) echo "product_term_check: $(grep -c . "$tmp/out") mention(s) of a product term or an object id in a row; the row is restated technology-level, or its words moved to the spec folder, before anything is written (docs/config/ports.md section The product-term guard)" >&2 ;;
  4) die "a file could not be read; nothing is clean until every file is" ;;
  6) die "the product-term list holds an entry that would flag everything (see above); nothing was checked" ;;
  *) die "perl failed (exit $rc); the scan did not complete, so nothing is clean" ;;
esac
exit "$rc"
