#!/usr/bin/env bash
# private_name_check.sh — refuse text that names a private repository (zheref/hatsu#149).
#
# docs/PUBLIC-REDACTION.md § *The rule*: no private repository is named anywhere in this
# repository's content, and § *Scope* extends it to GitHub issue bodies. Nothing checked either, so
# both drifted; the first redaction pass then missed a bare name because it searched slugs only.
# This guard compares text against the LIVE private list, on the maintainer's own credentials --
# every private repository the credential can see, whoever owns it:
#
#   gh api 'user/repos?visibility=private&per_page=100' --paginate -q '.[].full_name'
#
# --owner <login> ADDS that owner's `gh repo list --visibility private` to it (never narrows it: a
# narrower list is a quieter guard). The list is never committed to this public repository and never
# cached in the tree; a CI form needs it as a secret, passed through --names-file, as a fixture does.
# A list that reads EMPTY is a refusal (exit 2), never a pass: a token that cannot see private
# repositories, or an unset secret written to a file, would otherwise read green.
#
# Matching: each private repository's NAME (the part after the owner), case-insensitive, whole-word,
# taken literally (`-` and `.` are part of the name, never regex). A word is a run of [A-Za-z0-9-]:
# `name` inside `name-tools` is another word. `_` and `.` BOUND a word, failing closed: `_name_` and
# `__name__` (markdown emphasis), `my_name`, `name.git`, `name.md` and a sentence's `name.` all match,
# and `owner/name` slugs and URLs match through the name. A line holding `%`, `&`, `<`, `\`, `*`, a
# backtick or a non-ASCII byte is also read normalised, twice -- %XX decoded, UTF-8 decoded, HTML
# entities decoded, inline tags and backslash escapes before punctuation dropped, NFKC applied, format
# characters (zero-width, soft hyphen) deleted and every dash folded to `-`; then once more with HTML
# comments, `*` and backticks removed, so `na**me**`, `na*me*`, `na<!-- -->me` and ``na`m`e`` read
# as the name -- and a hit is reported at its original line. Those transformations are what is
# handled; nothing else is claimed. `_` is not removed inside a word: CommonMark never renders an
# intraword `_` as emphasis, so `na_me` shows as written and removing it would only flag snake_case.
# Under --tree, paths and symlink targets are names too, and a UTF-16 file WITH a BOM (U+FEFF) is
# decoded; one without, like any binary file (a NUL in its first 8 KiB) or anything that is not a
# regular file, is skipped and COUNTED in the ok line, never silently.
#
# The output NEVER prints a private name: a hit is `<file>:<line>: private repository #<k>`, an index
# into the list (sorted with LC_ALL=C, after the ignore file); a file path or --label that contains a
# name is printed with the name replaced by `<private #k>`, and one that names it only once normalised
# (`%7A...`) is withheld whole: `<path withheld: private #k>` or `<label withheld: private #k>`.
# `--resolve <k>` prints entry k to a
# terminal only (stderr, refused when stderr is not a terminal), so an index never reaches a log as a
# name. The ok line carries the list's size only under --verbose.
#
# Exemptions (§ *What is deliberately not redacted*) are explicit and named, never inferred. Of that
# list only one entry is a repository name: the predecessor generator's marker, quoted as a marker
# (hatsu:limbo matches it byte for byte, so it cannot be placeheld). Its name is read at run time from
# limbo's own marker line (`claude/skills/limbo/SKILL.md` beside this script, or --marker-source,
# which only the fixture passes), and it is exempt ONLY where it stands in the exact shape
# `<!-- GENERATED from <that name>@`, at that position (limbo's own residue and its A/B table quote
# the marker mid-line, so the shape is not anchored to a line start). Any other name in that shape,
# the shape without its `<!-- ` or its `@`, or the same name anywhere else on the line -- spelt
# plainly or through any normalisation above -- is a hit. With no readable marker source nothing is
# exempt. There is no line marker and no path
# allowlist, so an exemption cannot be added without changing this script and its fixture.
# Out of tree:
#   - --ignore-file <path> (default ${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/redaction-ignore, read
#     when present): private names the maintainer has ruled too generic to police -- a repository
#     called after an ordinary dictionary word -- one per line. `owner/name` ignores that repository
#     only; a bare `name` ignores the name under every owner. It lives on the maintainer's machine,
#     NEVER in this tree: committing it would name the very repositories it lists. Only the
#     maintainer writes it (hatsu:file § 8). Both the ok line and a refusal say how many were ignored.
#     An empty or comment-only ignore file ignores nothing; one that ignores EVERY name is a refusal
#     (exit 2) unless --allow-empty is given.
#
# Usage:
#   private_name_check.sh [--owner <login>]... [--names-file <path> [--allow-empty]]
#                         [--target <owner/name>] [--ignore-file <path>] [--label <name>]
#                         [--verbose] [--tree <root>] [<file>|-]...
#   private_name_check.sh [--owner <login>]... [--names-file <path>] [--ignore-file <path>] --resolve <k>
#                         (pass the same list flags as the run that printed k: the index is into that list)
#
#   --owner        add this owner's private repositories to the credential's list; repeatable.
#   --names-file   one `owner/name` or `name` per line (`#` comments, blanks ignored), INSTEAD of gh.
#   --allow-empty  a list left with no names (an empty names file, or every name ignored) is clean
#                  (exit 0) instead of a refusal.
#   --target       the repository the text is going to. A private or internal target is skipped
#                  (exit 0, `skipped`): naming a private repository inside another private one leaks
#                  nothing. An unreadable visibility is a refusal, never a skip.
#   --tree <root>  check every tracked and untracked-not-ignored file under <root> (git ls-files):
#                  contents, path strings and symlink targets.
#   -              read stdin (once), reported as --label (default `<stdin>`).
#
# Exit codes: 0 clean (or skipped), 1 a private name found, 2 wiring — gh missing, unauthenticated or
# failing, a list that may be truncated or reads empty, an unreadable file or names file, stdin given
# twice, a bad argument, perl missing or lacking Encode / Unicode::Normalize, every name ignored, or
# the scan failing in perl. A guard that cannot read the list never reads green.
set -u

LIMIT=1000

die() { printf 'private_name_check: %s\n' "$*" >&2; exit 2; }

here="$(cd "$(dirname "$0")" && pwd)"
owners=()
names_file=""
allow_empty=0
target=""
ignore_file="${XDG_CONFIG_HOME:-$HOME/.config}/hatsu/redaction-ignore"
ignore_explicit=0
label="<stdin>"
tree=""
verbose=0
resolve=""
marker_source="$here/../claude/skills/limbo/SKILL.md"
inputs=()
stdin_seen=0

while [ $# -gt 0 ]; do
  case "$1" in
    --owner) [ $# -ge 2 ] && [ -n "$2" ] || die "--owner needs a login"; owners+=("$2"); shift 2 ;;
    --names-file) [ $# -ge 2 ] && [ -n "$2" ] || die "--names-file needs a path"; names_file="$2"; shift 2 ;;
    --allow-empty) allow_empty=1; shift ;;
    --target) [ $# -ge 2 ] && [ -n "$2" ] || die "--target needs owner/name"; target="$2"; shift 2 ;;
    --ignore-file) [ $# -ge 2 ] && [ -n "$2" ] || die "--ignore-file needs a path"; ignore_file="$2"; ignore_explicit=1; shift 2 ;;
    --label) [ $# -ge 2 ] && [ -n "$2" ] || die "--label needs a name"; label="$2"; shift 2 ;;
    --tree) [ $# -ge 2 ] && [ -n "$2" ] || die "--tree needs a root"; tree="$2"; shift 2 ;;
    --verbose) verbose=1; shift ;;
    --resolve) [ $# -ge 2 ] && [ -n "$2" ] || die "--resolve needs an index"; resolve="$2"; shift 2 ;;
    --marker-source) [ $# -ge 2 ] && [ -n "$2" ] || die "--marker-source needs a path"; marker_source="$2"; shift 2 ;;
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
  [ -n "$tree" ] || [ ${#inputs[@]} -gt 0 ] || die "nothing to check: pass files, '-' or --tree <root>"
fi

tmp="$(mktemp -d)" || die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

# --- the target: a private destination leaks nothing ------------------------------------------
if [ -n "$target" ] && [ -z "$resolve" ]; then
  case "$target" in */*) : ;; *) die "--target must be owner/name (the value is not echoed: it may name a private repository)" ;; esac
  command -v gh >/dev/null 2>&1 || die "gh is required to read --target's visibility"
  vis="$(gh repo view "$target" --json visibility -q .visibility 2>"$tmp/vis.err")" \
    || die "could not read --target's visibility (gh exited non-zero; its message is not echoed, since it may name the repository)"
  case "$vis" in
    PRIVATE|INTERNAL) echo "private_name_check: skipped -- the --target repository is $vis, so naming a private repository there leaks nothing"; exit 0 ;;
    PUBLIC) : ;;
    *) die "unexpected visibility for --target (not PUBLIC, PRIVATE or INTERNAL)" ;;
  esac
fi

# --- the private list: live, or a names file ----------------------------------------------------
list="$tmp/names"
if [ -n "$names_file" ]; then
  [ -f "$names_file" ] && [ -r "$names_file" ] || die "cannot read names file '$names_file'"
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$names_file" | sed -e '/^$/d' > "$list" \
    || die "cannot read names file '$names_file'"
  source_desc="the names file"
else
  command -v gh >/dev/null 2>&1 || die "gh is required to read the private repository list (or pass --names-file)"
  gh api 'user/repos?visibility=private&per_page=100' --paginate -q '.[].full_name' \
    > "$list" 2>"$tmp/all.err" || die "gh could not list the credential's private repositories ($(head -1 "$tmp/all.err"))"
  for o in "${owners[@]+"${owners[@]}"}"; do
    gh repo list "$o" --visibility private --limit "$LIMIT" --json nameWithOwner -q '.[].nameWithOwner' \
      > "$tmp/o.list" 2>"$tmp/o.err" || die "gh repo list $o failed ($(head -1 "$tmp/o.err"))"
    n="$(grep -c . "$tmp/o.list")"
    [ "$n" -lt "$LIMIT" ] || die "gh repo list $o returned $n repositories, the --limit; the list may be truncated"
    cat "$tmp/o.list" >> "$list"
  done
  grep -q . "$list" || die "the private repository list read EMPTY -- the credential may not see private repositories (gh auth status; the token needs the repo scope), so nothing would be checked"
  source_desc="live"
fi
LC_ALL=C sort -u -o "$list" "$list"
if ! grep -q . "$list"; then
  [ "$allow_empty" -eq 1 ] || die "the names file holds no names; pass --allow-empty if that is meant (an unset CI secret reads exactly like this)"
fi
n_ignored=0
if [ -e "$ignore_file" ] || [ "$ignore_explicit" -eq 1 ]; then
  [ -f "$ignore_file" ] && [ -r "$ignore_file" ] || die "cannot read ignore file '$ignore_file'"
  sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' "$ignore_file" \
    | tr '[:upper:]' '[:lower:]' | LC_ALL=C sort -u > "$tmp/ignore"
  # `owner/name` drops that entry; a bare `name` drops the name under every owner. Case-insensitive.
  # The ignore set is read in BEGIN, never by NR==FNR: an empty ignore file would otherwise make awk
  # read the LIST as the ignore set and drop every name.
  awk -v igf="$tmp/ignore" 'BEGIN { while ((getline l < igf) > 0) ig[l]=1; close(igf) }
    { e=tolower($0); n=e; sub(/^.*\//, "", n); if (!(e in ig) && !(n in ig)) print }' \
    "$list" > "$tmp/kept"
  n_ignored=$(( $(grep -c . "$list") - $(grep -c . "$tmp/kept") ))
  cp "$tmp/kept" "$list"
fi
n_names="$(grep -c . "$list")"
if [ "$n_names" -eq 0 ] && [ "$n_ignored" -gt 0 ] && [ "$allow_empty" -ne 1 ]; then
  die "every private name is ignored ($n_ignored by the ignore file), so nothing would be checked; pass --allow-empty if that is meant"
fi
n_owners="$(grep '/' "$list" | sed 's#/.*##' | LC_ALL=C sort -u | grep -c .)"

# --- --resolve: one entry, to a terminal only ---------------------------------------------------
if [ -n "$resolve" ]; then
  case "$resolve" in *[!0-9]*|0) die "--resolve needs a positive index, got '$resolve'" ;; esac
  [ -t 2 ] || die "--resolve prints only to a terminal (stderr is not one), so a name never reaches a log"
  [ "$resolve" -le "$n_names" ] || die "--resolve $resolve: the list has $n_names entries"
  printf '#%s: %s\n' "$resolve" "$(sed -n "${resolve}p" "$list")" >&2
  exit 0
fi

# --- what to read ------------------------------------------------------------------------------
: > "$tmp/tree.z"
if [ -n "$tree" ]; then
  [ -d "$tree" ] || die "--tree '$tree' is not a directory"
  git -C "$tree" ls-files -z -co --exclude-standard > "$tmp/tree.z" 2>"$tmp/tree.err" \
    || die "git ls-files failed under '$tree' ($(head -1 "$tmp/tree.err"))"
fi
: > "$tmp/stdin"
[ "$n_stdin" -eq 0 ] || cat > "$tmp/stdin" || die "cannot read stdin"

if [ "$n_names" -eq 0 ]; then
  echo "private_name_check: ok -- no private repositories to look for (--allow-empty; $n_ignored ignored)"
  exit 0
fi

# One perl pass; see the header for the word, the normalisation and the exemption.
PNC_NAMES="$list" PNC_ROOT="$tree" PNC_TREELIST="$tmp/tree.z" PNC_LABEL="$label" PNC_STDIN="$tmp/stdin" \
PNC_MARKER="$marker_source" PNC_SKIPPED="$tmp/skipped" perl -e '
  use strict; use warnings;
  use Encode qw(decode encode FB_DEFAULT);
  use Unicode::Normalize qw(NFKC);
  open(my $nf, "<", $ENV{PNC_NAMES}) or exit 3;
  my @entries = grep { length } map { chomp; $_ } <$nf>; close $nf;
  my (%idx, @names);
  for my $i (0 .. $#entries) {
    (my $n = $entries[$i]) =~ s{^.*/}{};
    my $k = lc $n;
    next if exists $idx{$k};          # first entry wins; a case twin across owners shares its index
    $idx{$k} = $i + 1; push @names, $n;
  }
  my $alt = join "|", map { quotemeta } sort { length($b) <=> length($a) } @names;
  my $re = qr/(?<![A-Za-z0-9\-])($alt)(?![A-Za-z0-9\-])/i;

  # The predecessor name, read from limbo marker line; none readable means nothing is exempt.
  my $pred = "";
  if (open(my $mf, "<", $ENV{PNC_MARKER})) {
    while (my $l = <$mf>) { if ($l =~ /<!-- GENERATED from ([A-Za-z0-9._-]+)@/) { $pred = lc $1; last } }
    close $mf;
  }
  sub exempt {
    my ($l, $b, $e, $name) = @_;
    return 0 unless length $pred && lc($name) eq $pred && substr($l, $e, 1) eq "@";
    return substr($l, 0, $b) =~ /<!-- GENERATED from \z/ ? 1 : 0;
  }
  sub redact { my $s = shift; $s =~ s/$re/"<private #" . $idx{lc $1} . ">"/ge; return $s }

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
  # The second normalised reading: HTML comments, `*` and backticks removed (intraword emphasis and
  # code spans that render as one word). `_` stays: an intraword `_` never renders as emphasis.
  sub norm2 { my $s = shift; $s =~ s/<!--.*?-->//g; $s =~ s/[*`]//g; return $s }
  sub trig { return $_[0] =~ /[%&<\\*`]|[^\x00-\x7F]/ }
  # What a shown path or label may print: raw matches replaced by their index; one that names a
  # repository only once normalised is withheld whole.
  sub safe {
    my ($s, $kind) = @_;
    my $r = redact($s);
    return $r unless trig($r);
    my $m = norm($r);
    for my $v ($m, norm2($m)) { return "<$kind withheld: private #" . $idx{lc $1} . ">" if $v =~ $re }
    return $r;
  }

  my ($hits, $bad, $skipped) = (0, 0, 0);
  sub hit { my ($shown, $n, $k, $how) = @_; printf "%s:%s: private repository #%d%s -- redact it to the legend placeholder (docs/PUBLIC-REDACTION.md)\n", $shown, $n, $k, $how; $hits++ }
  sub line {
    my ($l, $shown, $n) = @_;
    my %seen;   # names already REPORTED on this line; an exempt match never counts as reported
    while ($l =~ /$re/g) {
      my ($b, $e, $name) = ($-[1], $+[1], $1);
      next if exempt($l, $b, $e, $name);
      hit($shown, $n, $idx{lc $name}, ""); $seen{lc $name} = 1;
    }
    return unless trig($l);
    my $m = norm($l);
    for my $v ($m, norm2($m)) {
      while ($v =~ /$re/g) {
        my ($b, $e, $name) = ($-[1], $+[1], $1);
        next if $seen{lc $name};
        next if exempt($v, $b, $e, $name);
        hit($shown, $n, $idx{lc $name}, " (spelt through an escape, entity, encoding, markup or invisible character)"); $seen{lc $name} = 1;
      }
    }
  }
  sub text { my ($t, $shown) = @_; my $n = 0; for my $l (split /\n/, $t, -1) { $n++; line($l, $shown, $n) } }
  sub scan {
    my ($path, $shown) = @_;
    my $fh;
    local $/ = "\n";
    unless (-f $path && open($fh, "<:raw", $path)) { print STDERR "private_name_check: cannot read $shown\n"; $bad = 1; return; }
    my $head = ""; read($fh, $head, 8192);
    if ($head =~ /\A(\xFF\xFE|\xFE\xFF)/) {
      local $/; seek($fh, 0, 0); my $all = <$fh>; close $fh;
      text(encode("UTF-8", decode("UTF-16", $all, FB_DEFAULT)), $shown);
      return;
    }
    if (index($head, "\0") >= 0) { close $fh; $skipped++; return; }
    seek($fh, 0, 0);
    while (my $l = <$fh>) { chomp $l; line($l, $shown, $.) }
    close $fh;
  }
  my $ok = eval {
  for my $a (@ARGV) {
    if ($a eq "-") { scan($ENV{PNC_STDIN}, safe($ENV{PNC_LABEL}, "label")) } else { scan($a, safe($a, "path")) }
  }
  if (length $ENV{PNC_ROOT}) {
    open(my $tl, "<:raw", $ENV{PNC_TREELIST}) or exit 3;
    local $/ = "\0";
    while (my $p = <$tl>) {
      chomp $p; next unless length $p;
      my $sp = safe($p, "path");
      line($p, $sp, "path");
      my $full = "$ENV{PNC_ROOT}/$p";
      if (-l $full) { my $t = readlink($full); line(defined $t ? $t : "", $sp, "symlink-target") }
      elsif (-f $full) { scan($full, $sp) }
      else { $skipped++ }
    }
    close $tl;
  }
  1 };
  # A die inside the scan is its own exit, never one a caller could read as hits (1) or clean (0).
  unless ($ok) { print STDERR "private_name_check: perl: " . redact($@ // "died"); exit 5 }
  open(my $sk, ">", $ENV{PNC_SKIPPED}) or exit 3; print $sk "$skipped\n"; close $sk;
  exit 4 if $bad;
  exit($hits ? 1 : 0);
' -- "${inputs[@]+"${inputs[@]}"}" > "$tmp/out"
rc=$?
cat "$tmp/out"
skipped="$(cat "$tmp/skipped" 2>/dev/null || echo '?')"
size=""
[ "$verbose" -eq 1 ] && size="; checked against $n_names"
case "$rc" in
  0) echo "private_name_check: ok -- no private repository named ($source_desc list, $n_owners owner(s)$size; $n_ignored ignored by the maintainer's ignore file; $skipped skipped as binary or not a regular file)" ;;
  1) echo "private_name_check: $(grep -c . "$tmp/out") mention(s) of a private repository ($n_ignored ignored by the maintainer's ignore file); nothing may be filed or published until they are redacted" >&2 ;;
  4) die "a file could not be read; nothing is clean until every file is" ;;
  *) die "perl failed (exit $rc); the scan did not complete, so nothing is clean" ;;
esac
exit "$rc"
