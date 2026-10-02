#!/usr/bin/env bash
# pr_development_link_check.sh — refuse a pull request whose closing issues are not linked both ways in
# GitHub's Development field (zheref/hatsu#203; claude/skills/shibari/SKILL.md § 3, ruling 2026-09-12).
#
#   scripts/pr_development_link_check.sh --pr <owner/name#N> [--fixture <dir>]
#   scripts/pr_development_link_check.sh --body <file> --target <owner/name>
#   scripts/pr_development_link_check.sh --self-test
#
# THE EXPECTED SET IS DERIVED FROM THE BODY, never restated. In the body's `## Associated issues`
# table (templates/pr-body.md), a row is a COMPLETES-ROW when its *Merging this* cell, emphasis and code
# marks stripped, begins with `completes` or `closes` and never says `part`; every other row (delivers
# part, part of, cited, prerequisite) is a NON-CLOSING row. The issue cell may hold a canonical URL,
# `owner/name#N` or `#N`; a bare `#N` beside a URL or `owner/name#N` in the same cell is ignored (it is
# the link text). The completes-rows are the expected closing set.
#
# Refused, each named on stderr (exit 1):
#   body        a completes-row with no separate closing keyword line for it — `Closes|Fixes|Resolves
#               <ref>` (any of GitHub's nine forms, an optional colon), alone on its line, outside a code
#               fence and an HTML comment, `owner/name#N` or a URL for a cross-repository issue; a
#               keyword line for an issue the table does not complete; a table row with no issue
#               reference; a table with no *Merging this* column
#   pr side     missing: an expected issue absent from the PR's closingIssuesReferences
#               extra:   anything else in closingIssuesReferences — a partial or cited issue included
#   issue side  missing: an expected issue whose closedByPullRequestsReferences does not list this PR
#               extra:   a non-closing row's issue that lists this PR there
# On a base that is not the repository's default branch, closing keywords do not link: the missing
# links are named with the remedy — link them through GitHub's Development sidebar, or the GraphQL
# linking the platform supports (no Nen verb exists for it), then re-run. A link is never claimed.
#
# --body/--target checks the body half alone, offline, before the PR is opened.
# --fixture <dir> reads the GitHub half from files instead of gh, so the self-test is hermetic:
#   <dir>/repo.json                       gh repo view <o/n> --json defaultBranchRef
#   <dir>/pr.json                         gh pr view <N> --repo <o/n> --json number,baseRefName,body,closingIssuesReferences
#   <dir>/issues/<owner>/<name>/<N>.json  gh issue view <N> --repo <o/n> --json number,closedByPullRequestsReferences
#   (owner and name lowercased)
#
# exit 0  the body names a keyword for every completes-row, and both directions match it exactly
# exit 1  at least one refusal; every one is listed on stderr
# exit 2  GitHub (or the fixture) could not be read, malformed JSON, jq missing, or a usage error
#
# Bash 3.2 portable: no associative arrays; sets are newline-delimited temp files.

usage() {
  echo "usage: pr_development_link_check.sh --pr <owner/name#N> [--fixture <dir>]" >&2
  echo "       pr_development_link_check.sh --body <file> --target <owner/name>" >&2
  echo "       pr_development_link_check.sh --self-test" >&2
}

die2() { echo "pr_development_link_check.sh: $*" >&2; exit 2; }

# parse_body <default owner/name> < body: prints one record per line, tab-separated —
#   ROW completes|other <o/n#N>    KW <o/n#N>    BADROW <cell>    NOMERGECOL <header>
parse_body() {
  awk -v def="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function refs(s, out,    n, u, t, k, found) {  # fills out[1..n] with normalised refs
      n = 0; found = 0; s = tolower(s)
      while (match(s, /https?:\/\/github\.com\/[a-z0-9_.-]+\/[a-z0-9_.-]+\/(issues|pull)\/[0-9]+/)) {
        u = substr(s, RSTART, RLENGTH); s = substr(s, 1, RSTART - 1) " " substr(s, RSTART + RLENGTH)
        sub(/^https?:\/\/github\.com\//, "", u); k = split(u, t, "/")
        out[++n] = t[1] "/" t[2] "#" t[4]; found = 1
      }
      while (match(s, /[a-z0-9_.-]+\/[a-z0-9_.-]+#[0-9]+/)) {
        out[++n] = substr(s, RSTART, RLENGTH); s = substr(s, 1, RSTART - 1) " " substr(s, RSTART + RLENGTH); found = 1
      }
      if (!found) while (match(s, /#[0-9]+/)) {
        out[++n] = def substr(s, RSTART, RLENGTH); s = substr(s, 1, RSTART - 1) " " substr(s, RSTART + RLENGTH)
      }
      return n
    }
    BEGIN { fence = 0; com = 0; sec = 0; hdr = 0 }
    {
      line = $0; sub(/\r$/, "", line)
      if (!com && line ~ /^[ \t]*(```|~~~)/) { fence = !fence; next }
      if (fence) next
      out = ""
      while (1) {
        if (com) { e = index(line, "-->"); if (!e) { line = ""; break }; line = substr(line, e + 3); com = 0 }
        s = index(line, "<!--"); if (!s) { out = out line; break }
        out = out substr(line, 1, s - 1); line = substr(line, s + 4); com = 1
      }
      line = out
      if (line ~ /^[ \t]*#+[ \t]/) {
        h = tolower(trim(line)); sub(/^#+[ \t]+/, "", h); sec = (h == "associated issues"); hdr = 0; next
      }
      t = trim(line); lt = tolower(t)
      if (lt ~ /^(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved):?[ \t]+[^ \t]+$/) {
        r = lt; sub(/^[a-z]+:?[ \t]+/, "", r)
        if (r ~ /^https?:\/\/github\.com\/[a-z0-9_.-]+\/[a-z0-9_.-]+\/issues\/[0-9]+$/ || r ~ /^[a-z0-9_.-]+\/[a-z0-9_.-]+#[0-9]+$/ || r ~ /^#[0-9]+$/) {
          if (refs(r, o) == 1) print "KW\t" o[1]
        }
      }
      if (!sec || t !~ /^\|/) next
      n = split(t, c, "|")
      if (!hdr) {
        icol = 0; mcol = 0
        for (k = 2; k <= n; k++) {
          cell = tolower(trim(c[k]))
          if (!icol && cell ~ /issue/) icol = k
          if (!mcol && cell ~ /merging/) mcol = k
        }
        if (!icol) icol = 2
        if (!mcol) print "NOMERGECOL\t" t
        hdr = 1; next
      }
      if (t ~ /^[|: \t-]+$/) next
      if (!mcol) next
      m = tolower(c[mcol]); gsub(/[*_`]/, "", m); m = trim(m)
      cls = (m ~ /^(completes|closes)([^a-z]|$)/ && m !~ /part/) ? "completes" : "other"
      k = refs(c[icol], o)
      if (k == 0) { print "BADROW\t" trim(c[icol]); next }
      for (j = 1; j <= k; j++) print "ROW\t" cls "\t" o[j]
    }
  '
}

in_set() { grep -Fqx -- "$1" "$2" 2>/dev/null; }   # in_set <item> <file>

# fetch <kind> <owner/name> [<N>]: prints gh JSON (or the fixture's), validated; exit 2 on failure.
fetch() {
  local kind="$1" repo="$2" num="$3" out file
  if [ -n "$fixture" ]; then
    case "$kind" in
      repo) file="$fixture/repo.json" ;;
      pr) file="$fixture/pr.json" ;;
      issue) file="$fixture/issues/$repo/$num.json" ;;
    esac
    [ -f "$file" ] && [ -r "$file" ] || die2 "cannot read $kind $repo${num:+#$num}: fixture file '$file' is missing"
    out="$(cat "$file")"
  else
    case "$kind" in
      repo) out="$(gh repo view "$repo" --json defaultBranchRef 2>/dev/null)" ;;
      pr) out="$(gh pr view "$num" --repo "$repo" --json number,baseRefName,body,closingIssuesReferences 2>/dev/null)" ;;
      issue) out="$(gh issue view "$num" --repo "$repo" --json number,closedByPullRequestsReferences 2>/dev/null)" ;;
    esac || die2 "GitHub could not be read: $kind $repo${num:+#$num}"
  fi
  printf '%s\n' "$out" | jq -e 'type == "object"' >/dev/null 2>&1 || die2 "malformed JSON for $kind $repo${num:+#$num}"
  printf '%s\n' "$out"
}

# check_body <body file> <owner/name> <work dir>: writes expected/other/kw sets; prints refusals; 0/1.
check_body() {
  local body="$1" repo="$2" w="$3" bad=0 kind a b r
  parse_body "$repo" < "$body" > "$w/parsed"
  : > "$w/expected"; : > "$w/other"; : > "$w/kw"
  while IFS="$(printf '\t')" read -r kind a b; do
    case "$kind" in
      ROW) if [ "$a" = completes ]; then in_set "$b" "$w/expected" || echo "$b" >> "$w/expected"
           else in_set "$b" "$w/other" || echo "$b" >> "$w/other"; fi ;;
      KW) in_set "$a" "$w/kw" || echo "$a" >> "$w/kw" ;;
      BADROW) echo "body: an Associated issues row names no issue reference: '$a'" >&2; bad=1 ;;
      NOMERGECOL) echo "body: the Associated issues table has no 'Merging this' column: '$a'" >&2; bad=1 ;;
    esac
  done < "$w/parsed"
  while read -r r; do
    in_set "$r" "$w/other" && { echo "body: $r is a completes-row and a non-closing row at once" >&2; bad=1; }
    in_set "$r" "$w/kw" || { echo "body: completes-row $r has no separate closing keyword line (Closes $r, alone on its line)" >&2; bad=1; }
  done < "$w/expected"
  while read -r r; do
    if in_set "$r" "$w/other"; then echo "body: closing keyword for $r, which the table marks as not completed by this PR (merging would close it)" >&2; bad=1
    elif ! in_set "$r" "$w/expected"; then echo "body: closing keyword for $r, which the Associated issues table does not list as completed" >&2; bad=1; fi
  done < "$w/kw"
  return $bad
}

check_pr() {  # check_pr <owner/name#N> <work dir>
  local self="$1" w="$2" repo num pr base def bad=0 missing=0 r o n set
  repo="${self%#*}"; num="${self##*#}"
  def="$(fetch repo "$repo")" || exit 2
  pr="$(fetch pr "$repo" "$num")" || exit 2
  base="$(printf '%s\n' "$pr" | jq -r '.baseRefName // empty')"
  def="$(printf '%s\n' "$def" | jq -r '.defaultBranchRef.name // empty')"
  [ -n "$base" ] && [ -n "$def" ] || die2 "baseRefName or defaultBranchRef missing for $self"
  printf '%s\n' "$pr" | jq -r '.body // ""' > "$w/body"
  printf '%s\n' "$pr" | jq -r '.closingIssuesReferences // [] | .[] | "\(.repository.owner.login)/\(.repository.name)#\(.number)" | ascii_downcase' > "$w/closing" \
    || die2 "closingIssuesReferences unreadable for $self"
  check_body "$w/body" "$repo" "$w" || bad=1
  while read -r r; do
    in_set "$r" "$w/closing" || { echo "pr side: missing: $r is completed by the body but absent from $self closingIssuesReferences" >&2; bad=1; missing=1; }
  done < "$w/expected"
  while read -r r; do
    in_set "$r" "$w/expected" && continue
    if in_set "$r" "$w/other"; then echo "pr side: extra: $r is in $self closingIssuesReferences but the body marks it as not completed (merging would close it)" >&2
    else echo "pr side: extra: $r is in $self closingIssuesReferences but the Associated issues table does not list it as completed" >&2; fi
    bad=1
  done < "$w/closing"
  for set in expected other; do
    while read -r r; do
      o="${r%#*}"; n="${r##*#}"
      fetch issue "$o" "$n" > "$w/issue.json" || exit 2
      jq -r '.closedByPullRequestsReferences // [] | .[] | "\(.repository.owner.login)/\(.repository.name)#\(.number)" | ascii_downcase' < "$w/issue.json" > "$w/closedby" \
        || die2 "closedByPullRequestsReferences unreadable for $r"
      if [ "$set" = expected ]; then
        in_set "$self" "$w/closedby" || { echo "issue side: missing: $r does not list $self in closedByPullRequestsReferences" >&2; bad=1; missing=1; }
      else
        in_set "$self" "$w/closedby" && { echo "issue side: extra: $r lists $self in closedByPullRequestsReferences but the body marks it as not completed" >&2; bad=1; }
      fi
    done < "$w/$set"
  done
  if [ "$missing" -eq 1 ] && [ "$base" != "$def" ]; then
    echo "base '$base' is not the default branch '$def': closing keywords do not link here. Link the missing issues through GitHub's Development sidebar (or the platform's GraphQL linking; there is no Nen verb), then re-run. No link is claimed." >&2
  fi
  return $bad
}

self_test() {
  local st_self st_dir st_fails=0 args table m_body
  st_self="$(cd -P -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")"
  st_dir="$(mktemp -d)"; trap 'rm -rf "$st_dir"' EXIT
  refs_json() {  # refs_json <o/n#N ...>: a JSON array of gh reference objects
    local out="" r
    for r in "$@"; do
      out="$out${out:+,}{\"number\":${r##*#},\"repository\":{\"name\":\"$(printf '%s' "${r%#*}" | cut -d/ -f2)\",\"owner\":{\"login\":\"${r%%/*}\"}}}"
    done
    printf '[%s]' "$out"
  }
  mk() {  # mk <case> <base> <body> <closing refs, space-separated o/n#N>
    local d="$st_dir/$1"
    mkdir -p "$d"
    printf '{"defaultBranchRef":{"name":"main"}}\n' > "$d/repo.json"
    # shellcheck disable=SC2086
    jq -n --arg base "$2" --arg body "$3" --argjson c "$(refs_json $4)" \
      '{number:7,baseRefName:$base,body:$body,closingIssuesReferences:$c}' > "$d/pr.json"
  }
  issue() {  # issue <case> <o/n#N> <closed-by refs>
    local d="$st_dir/$1/issues/${2%#*}"
    mkdir -p "$d"
    # shellcheck disable=SC2086
    printf '{"number":%s,"closedByPullRequestsReferences":%s}\n' "${2##*#}" "$(refs_json $3)" > "$d/${2##*#}.json"
  }
  run() {  # run <label> <want exit> <case> [stderr substring]
    local rc
    bash "$st_self" --pr octo/demo#7 --fixture "$st_dir/$3" > /dev/null 2> "$st_dir/$3.err"; rc=$?
    if [ "$rc" -eq "$2" ] && { [ -z "$4" ] || grep -Fq -- "$4" "$st_dir/$3.err"; }; then echo "ok    $1"
    else echo "FAIL  $1: want $2${4:+ with '$4'}, got $rc: $(head -3 "$st_dir/$3.err")"; st_fails=$((st_fails + 1)); fi
  }
  table='## Associated issues

| Issue | Scope this PR implements | Merging this |
|---|---|---|'
  m_body="$table
| https://github.com/octo/demo/issues/3 | all of it | **completes it** |
| https://github.com/octo/demo/issues/4 | the first half | **delivers part** |

Closes #3

## Agent attribution"
  mk matched main "$m_body" "octo/demo#3"; issue matched octo/demo#3 "octo/demo#7"; issue matched octo/demo#4 ""
  run "matched: completes-row keyworded and linked both ways, partial unlinked" 0 matched

  mk nokw main "$table
| https://github.com/octo/demo/issues/3 | all of it | **completes it** |" "octo/demo#3"; issue nokw octo/demo#3 "octo/demo#7"
  run "a completes-row with no keyword line is refused" 1 nokw "has no separate closing keyword line"

  mk fenced main "$table
| https://github.com/octo/demo/issues/3 | all of it | **closes it** |

\`\`\`
Closes #3
\`\`\`
<!-- Closes #3 -->" "octo/demo#3"; issue fenced octo/demo#3 "octo/demo#7"
  run "a keyword inside a code fence or HTML comment does not count" 1 fenced "has no separate closing keyword line"

  mk inline main "$table
| https://github.com/octo/demo/issues/3 | all of it | **completes it** |

This PR closes #3 and more." "octo/demo#3"; issue inline octo/demo#3 "octo/demo#7"
  run "a keyword inside a sentence is not a separate keyword line" 1 inline "has no separate closing keyword line"

  mk nondefault feature/x "$m_body" ""; issue nondefault octo/demo#3 ""; issue nondefault octo/demo#4 ""
  run "a non-default base names the unlinked issue" 1 nondefault "pr side: missing: octo/demo#3"
  run "a non-default base states the Development-sidebar remedy" 1 nondefault "Development sidebar"

  mk nondeflinked feature/x "$m_body" "octo/demo#3"; issue nondeflinked octo/demo#3 "octo/demo#7"; issue nondeflinked octo/demo#4 ""
  run "a non-default base linked by hand, verified both ways, passes" 0 nondeflinked

  mk partkw main "$table
| https://github.com/octo/demo/issues/3 | all of it | **completes it** |
| https://github.com/octo/demo/issues/4 | the first half | Part of it |

Closes #3
Closes #4" "octo/demo#3 octo/demo#4"; issue partkw octo/demo#3 "octo/demo#7"; issue partkw octo/demo#4 "octo/demo#7"
  run "a Part of issue keyworded is refused in the body" 1 partkw "closing keyword for octo/demo#4"
  run "a Part of issue linked is an extra on the PR side" 1 partkw "pr side: extra: octo/demo#4"
  run "a Part of issue listing the PR is an extra on the issue side" 1 partkw "issue side: extra: octo/demo#4"

  mk partlinked main "$m_body" "octo/demo#3 octo/demo#4"; issue partlinked octo/demo#3 "octo/demo#7"; issue partlinked octo/demo#4 "octo/demo#7"
  run "a partial issue linked by hand with no keyword is still refused" 1 partlinked "pr side: extra: octo/demo#4"

  mk cited main "$m_body
Closes #9" "octo/demo#3 octo/demo#9"; issue cited octo/demo#3 "octo/demo#7"; issue cited octo/demo#4 ""
  run "a keyword and a link for an issue the table never lists are refused" 1 cited "pr side: extra: octo/demo#9"

  mk xrepo main "$table
| [OT-IS-#5](https://github.com/octo/other/issues/5) | the consumer half | **completes it** |

Fixes octo/other#5" "octo/other#5"; issue xrepo octo/other#5 "octo/demo#7"
  run "a cross-repository completes-row keyworded and linked passes" 0 xrepo

  mk xrepobare main "$table
| https://github.com/octo/other/issues/5 | the consumer half | **completes it** |

Fixes #5" "octo/demo#5"; issue xrepobare octo/other#5 ""
  run "a cross-repository issue keyworded as a bare #N is refused" 1 xrepobare "completes-row octo/other#5 has no separate closing keyword line"

  mk reverse main "$m_body" "octo/demo#3"; issue reverse octo/demo#3 ""; issue reverse octo/demo#4 ""
  run "the reverse side missing is refused" 1 reverse "issue side: missing: octo/demo#3 does not list octo/demo#7"

  mk none main "## Why

No associated issue." ""
  run "a PR with no associated issue and no link passes" 0 none
  mk nonelinked main "## Why

No associated issue." "octo/demo#3"
  run "a PR with no associated issue but a link is refused" 1 nonelinked "pr side: extra: octo/demo#3"

  mk nomerge main "## Associated issues

| Issue | Scope |
|---|---|
| #3 | all |" ""
  run "a table with no Merging this column is refused" 1 nomerge "no 'Merging this' column"

  mk badrow main "$table
| the login bug | all of it | **completes it** |" ""
  run "a row with no issue reference is refused" 1 badrow "names no issue reference"

  mk noissue main "$m_body" "octo/demo#3"
  run "a missing issue fixture is exit 2" 2 noissue "missing"
  mkdir -p "$st_dir/nopr"
  run "a missing pr fixture is exit 2" 2 nopr "missing"
  mk badjson main "$m_body" ""; echo "not json" > "$st_dir/badjson/pr.json"
  run "malformed JSON is exit 2" 2 badjson "malformed JSON"

  # Live mode through a stub gh, which serves the matched fixture by argument.
  mkdir -p "$st_dir/bin"
  cat > "$st_dir/bin/gh" <<'STUB'
#!/usr/bin/env bash
[ -n "$STUB_FAIL" ] && exit 1
case "$1 $2" in
  "repo view") cat "$STUB_DIR/repo.json" ;;
  "pr view") cat "$STUB_DIR/pr.json" ;;
  "issue view") cat "$STUB_DIR/issues/$5/$3.json" ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$st_dir/bin/gh"
  PATH="$st_dir/bin:$PATH" STUB_DIR="$st_dir/matched" bash "$st_self" --pr octo/demo#7 >/dev/null 2>&1
  if [ $? -eq 0 ]; then echo "ok    live mode reads gh and passes the matched case"; else echo "FAIL  live mode matched"; st_fails=$((st_fails + 1)); fi
  PATH="$st_dir/bin:$PATH" STUB_DIR="$st_dir/reverse" bash "$st_self" --pr octo/demo#7 >/dev/null 2>&1
  if [ $? -eq 1 ]; then echo "ok    live mode refuses the reverse side missing"; else echo "FAIL  live mode reverse"; st_fails=$((st_fails + 1)); fi
  PATH="$st_dir/bin:$PATH" STUB_DIR="$st_dir/matched" STUB_FAIL=1 bash "$st_self" --pr octo/demo#7 >/dev/null 2>&1
  if [ $? -eq 2 ]; then echo "ok    GitHub unreadable is exit 2"; else echo "FAIL  GitHub unreadable"; st_fails=$((st_fails + 1)); fi

  printf '%s\n' "$m_body" > "$st_dir/body.md"
  bash "$st_self" --body "$st_dir/body.md" --target octo/demo >/dev/null 2>&1
  if [ $? -eq 0 ]; then echo "ok    --body passes a keyworded body before the PR exists"; else echo "FAIL  --body matched"; st_fails=$((st_fails + 1)); fi
  printf '%s\n' "$table" "| #3 | all | **completes it** |" > "$st_dir/body2.md"
  bash "$st_self" --body "$st_dir/body2.md" --target octo/demo >/dev/null 2>&1
  if [ $? -eq 1 ]; then echo "ok    --body refuses a completes-row with no keyword"; else echo "FAIL  --body no keyword"; st_fails=$((st_fails + 1)); fi

  for args in "--pr octo/demo" "--pr octo#7" "--nope" "" "--body $st_dir/missing.md --target octo/demo" "--body $st_dir/body.md" "--pr octo/demo#7 --fixture $st_dir/nodir"; do
    # shellcheck disable=SC2086
    bash "$st_self" $args >/dev/null 2>&1
    if [ $? -eq 2 ]; then echo "ok    usage error (2): '${args//$st_dir/<tmp>}'"; else echo "FAIL  usage error: '$args'"; st_fails=$((st_fails + 1)); fi
  done

  if [ "$st_fails" -eq 0 ]; then echo "pr_development_link_check.sh --self-test: all passed"; return 0; fi
  echo "pr_development_link_check.sh --self-test: $st_fails failed"; return 1
}

pr="" fixture="" body="" target=""
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) command -v jq >/dev/null 2>&1 || die2 "jq is required"; self_test; exit $? ;;
    --pr|--fixture|--body|--target)
      [ $# -ge 2 ] || { usage; exit 2; }
      case "$1" in --pr) pr="$2" ;; --fixture) fixture="$2" ;; --body) body="$2" ;; --target) target="$2" ;; esac
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "pr_development_link_check.sh: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done
command -v jq >/dev/null 2>&1 || die2 "jq is required"
work="$(mktemp -d)" || die2 "mktemp failed"; trap 'rm -rf "$work"' EXIT

if [ -n "$body" ]; then
  [ -z "$pr" ] && [ -z "$fixture" ] || { usage; exit 2; }
  printf '%s' "$target" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || { echo "pr_development_link_check.sh: --target must be <owner/name>" >&2; usage; exit 2; }
  [ -f "$body" ] && [ -r "$body" ] || die2 "'$body' is not a readable regular file"
  if check_body "$body" "$target" "$work"; then echo "pr development links: the body names a closing keyword for every completes-row and none for any other"; exit 0; fi
  echo "pr development links: body refused (claude/skills/shibari/SKILL.md § 3, Associated issues)" >&2; exit 1
fi

printf '%s' "$pr" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+$' || { echo "pr_development_link_check.sh: --pr must be <owner/name#N>" >&2; usage; exit 2; }
[ -z "$fixture" ] || [ -d "$fixture" ] || die2 "--fixture '$fixture' is not a directory"
self="$(printf '%s' "$pr" | tr '[:upper:]' '[:lower:]')"
if check_pr "$self" "$work"; then
  echo "pr development links: $self — every completes-row is keyworded and linked both ways, nothing extra"; exit 0
fi
echo "pr development links: $self refused (claude/skills/shibari/SKILL.md § 3, Associated issues)" >&2
exit 1
