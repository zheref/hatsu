#!/bin/sh
# guard-base-branch.sh — refuse a commit or a push while standing on the trunk.
#
# WHAT THIS IS
# A Claude Code `PreToolUse` hook matched on `Bash` (see hooks/hooks.json). It
# reads the command the model is about to run and, if that command commits or
# pushes while the working copy sits on the workflow BASE branch, exits 2 with a
# one-line reason. Exit 2 on PreToolUse blocks the tool call and hands the
# reason back to the model.
#
# It is NOT a nen-owned step. `breath` cuts the branch through
# `nen shu warmup --repo --branch`, and `kokusen` commits through
# `nen commit format`; both already refuse to work on the trunk. This hook is the
# reflex underneath them — the case where a skill was never invoked and a bare
# `git commit` was typed straight into Bash. A rule that only holds when the
# right skill was called is not a rule.
#
# THE BASE
# `branch.base` in the repository's nen/workflow.json, defaulting to `main`.
# The same value breath fast-forwards, ao pulls from, and shibari opens the PR
# against. It is read from the repository the write would land in, not from the
# session's own tree.
#
# HOW THE COMMAND IS READ — a parse, never a substring match
#   0. A shell wrapper is unwrapped first. `sh -c '<script>'` (and `bash`,
#      `zsh`, `dash`, `ksh`) RUNS <script>, so the quoted payload is recovered
#      and appended to the line as its own segment before anything else. A
#      wrapper whose payload cannot be recovered fails closed.
#   1. Every quoted span (`'…'` or `"…"`) is then replaced by the single token
#      `@`, so quoted text can contribute neither an operator nor a space nor
#      the word `git` to the parse. `echo 'git commit'` reads as `echo @`.
#      Three things happen around that masking, in this order, and each exists
#      because a real payload was misjudged without it:
#        a. A quoted span carrying the escape `\n` is a MULTI-LINE string. It is
#           masked first, while the payload is still one line, because the
#           per-line masking cannot see a span once the escape has become a real
#           newline — and a document quoting `git push` inside one would then be
#           read as a command.
#        b. The payload writes a newline as the two-character escape `\n`, so a
#           multi-line command arrives as ONE line. It is translated to real
#           newlines (protecting a backslash the command genuinely contains, so
#           that `tr … '\n'` is left alone), because a `cd` on its own line
#           moves the directory every later line writes in, and without the
#           translation the whole script is one segment whose first token is
#           whatever the first line assigned.
#        c. A heredoc BODY is data the command WRITES, not commands it runs. The
#           body is masked to `@`, so a document quoting `git push -u origin
#           HEAD` as evidence is not read as a push — the shape that refused a
#           write of this repository's own evidence file. The exception is an
#           opener that hands the body to a shell (`sh <<EOF`, `… | bash <<EOF`),
#           which RUNS it: that body is kept and parsed. `<<'EOF'` and `<<"EOF"`
#           are unquoted to `<<EOF` before masking so the opener survives it, and
#           a `<<` that is itself inside a quoted span is gone by then and opens
#           nothing. `<<<` is a here-string and has no body.
#   2. The masked text is split into segments on `;` `|` `&` `(` `)` and the
#      backtick, so `&&`, `||`, a pipeline, a subshell and `$( … )` all separate —
#      and on the newlines of 1b, so each line of a multi-line command is its own
#      segment.
#   3. A segment is a git call only when its FIRST token is `git`. Git's own
#      global options are walked past FROM A LIST — the value-taking forms
#      `-C <dir>`, `-c <k=v>`, `--git-dir <dir>`, `--work-tree <dir>`,
#      `--namespace <ns>`, `--super-prefix <p>`, `--attr-source <t>`,
#      `--config-env <e>`, their `--key=value` spellings, and the valueless
#      ones (`--no-pager`, `-p`, `--bare`, `--literal-pathspecs`, …) — and the
#      first token that is not an option is the SUBCOMMAND. A leading `-…` that
#      is NOT on the list is not walked past: whether it swallows the next token
#      is exactly what decides where the subcommand is, so it fails closed (see
#      below) instead of being guessed at.
#   4. Only the subcommands `commit` and `push` are writes. `commit-tree` is a
#      different token and is not one of them.
#   5. THE DIRECTORY GIT TARGETS IS THE DIRECTORY JUDGED — not the session's.
#      A segment's own repository-selecting options decide it: every `-C <dir>`
#      it carries, IN ORDER and CUMULATIVELY (git applies each one relative to
#      the last, so `git -C a -C b` runs in `a/b`), then `--work-tree` and
#      `--git-dir` resolved against that, exactly as git resolves them. Only a
#      segment carrying none of them is judged in the working directory. The
#      working directory is the payload `cwd` moved by any `cd` EARLIER IN THE
#      COMMAND — on the same line or on a line above it, since 1b makes the
#      payload's newlines real — because a write after a `cd` lands in the
#      repository it moved to. `--git-dir` is queried as
#      `git --git-dir=… branch --show-current`,
#      which reads the branch of a linked worktree's `.git` FILE as happily as
#      of a real directory; `nen/workflow.json` is then read from THE CHECKOUT
#      THAT BRANCH CAME FROM — the work tree when one was given, otherwise the
#      linked worktree git resolved the git dir to (`<common>/worktrees/<name>`
#      holds a `gitdir` file naming that worktree's own `.git`, whose directory
#      is the checkout), and only failing both, the common git dir's parent.
#      Reading the primary checkout's copy for a `--git-dir` aimed at a worktree
#      compares the worktree's branch against a base a different working tree
#      declared, which is the wrong base whenever the two differ.
#      A session standing on `main` that drives a worktree standing on a feature
#      branch — `git -C <worktree> push` — is therefore ALLOWED, and the mirror
#      case, a feature-branch session driving a checkout that stands on `main`,
#      is REFUSED. Reading the session's own branch would answer both wrongly.
#
# WHERE IT FAILS CLOSED
# Five forms are refused whatever branch the working copy is on, because in each
# the branch this hook can see is not the branch the write would land on:
#   - a line that both changes branch (`switch`, `checkout`, `branch -f|-m|-M`)
#     and writes (`commit`, `push`) — `git switch main && git commit -m x`;
#   - a repository-selecting path (`-C`, `--git-dir`, `--work-tree`) quoted in a
#     form this guard cannot recover — including TWO DIFFERENT quoted paths for
#     the same flag ANYWHERE ON THE LINE, whether both on one segment or one on
#     each of two, because recovery is line-global and cannot tell whose span is
#     whose: `git -C '<main>' commit -m x && git -C '<feat>' status` would
#     otherwise judge the commit against `<feat>`. Two IDENTICAL quoted paths
#     are not ambiguous and are read normally;
#   - a `git` segment carrying a `commit` or `push` token alongside a GLOBAL
#     OPTION THIS GUARD DOES NOT KNOW — an unknown `-…` may or may not swallow
#     the token after it, which is precisely what decides where the subcommand
#     and the `-C` path are, so the option is named in the refusal;
#   - a `git` segment carrying a `commit` or `push` token whose subcommand the
#     option walk could not establish for any other reason;
#   - a shell wrapper (`sh -c …`) whose payload cannot be read.
#
# WHAT IT DOES NOT DO
# It does not judge WHICH branch you are on beyond that one comparison, does not
# look at what is staged, and does not care about `--no-verify` (a hook the
# harness runs is not a git hook, so `--no-verify` does not reach it). Anything
# else it cannot read — a payload it cannot parse, a directory that is not a git
# repository, a detached HEAD — is exit 0: outside the four forms above this
# hook refuses on a fact, never on a doubt, because a PreToolUse hook that
# blocks on uncertainty blocks the session.
#
# TEST CASES — payload on stdin, {"cwd": "<dir>", "tool_input": {"command": "…"}}
# All sixty-three run live against a constructed fixture of three repositories
# and six checkouts — a trunk on `main`, a LINKED WORKTREE of it on `feat/x`, a
# second linked worktree of it on `b2` whose own checked-out workflow.json
# declares `b2`, a checkout on `main` under a path with spaces, a repository
# whose workflow.json declares `develop`, and a linked worktree of that one —
# with the command JSON-escaped as a real payload carries it. The transcripts
# are in docs/ab/guard-base-branch.md.
#   Standing on the base branch (`main`):
#     git commit -m x                          -> 2   blocked
#     git push                                 -> 2   blocked
#     git -C . commit -m x                     -> 2   blocked
#     git --no-pager commit -m x               -> 2   global option walked past
#     git -C . -c user.name=x commit -m y      -> 2   two globals walked past
#     git -c commit.gpgsign=false push origin HEAD -> 2
#     echo $(git commit -m x)                  -> 2   the subshell is a segment
#     git commit -m "a message"                -> 2   escaped quotes survive
#     git commit-tree -m x                     -> 0   not the `commit` token
#     echo "git commit"                        -> 0   escaped, still quoted
#     echo 'git commit'                        -> 0   quoted, not a git call
#     gh pr create --title 'git commit'        -> 0   quoted, and not git
#     git log --format='git push'              -> 0   quoted, not a git write
#     git status                               -> 0
#   Standing on a feature branch:
#     git commit -m x                          -> 0
#     git push                                 -> 0
#     git commit -m x && git push              -> 0   no branch change in it
#     git -C <a checkout on main> commit -m x  -> 2   the -C repo is judged
#     git -C '<a checkout on main with spaces in its path>' commit -m x -> 2
#     cd <a checkout on main> && git commit    -> 2   the cd is followed
#     cd '<the same, quoted, with spaces>' && git push                  -> 2
#     git switch main && git commit -m x       -> 2   compound, fails closed
#     git checkout main; git push              -> 2   compound, fails closed
#     git branch -f main HEAD && git push      -> 2   compound, fails closed
#     git --git-dir=<main>/.git --work-tree=<main> commit -m x -> 2
#     git --git-dir <main>/.git commit -m x    -> 2   separate-argument form
#     git --work-tree=<main> --git-dir=<main>/.git push -> 2
#     git --git-dir=<a feature checkout>/.git commit -m x -> 0
#     sh -c 'git commit -m x' (from a main checkout, via cd) -> 2
#     bash -c "cd <main> && git push"          -> 2   wrapper payload unwrapped
#     sh -c 'git status'                       -> 0   wrapper, but not a write
#     git --nonsense-flag commit -m x          -> 2   the option is not followed
#     bash -c $SCRIPT                          -> 0   no write token to refuse
#     npm run build                            -> 0
#     gh pr edit 29 --body 'we push on green'  -> 0   not git, and quoted
#   In a checkout whose workflow.json declares `branch.base: develop`, standing
#   on `develop`:
#     git commit -m x                          -> 2   the declared base is read
#     git switch -c feat/x                     -> 0   not a write
#   THE DIRECTORY GIT TARGETS, not the session's — the shape a worktree effort
#   actually types. From a session standing on `main` (cwd = the trunk), driving
#   a linked worktree that stands on `feat/x`:
#     git -C <worktree> push -u origin feat/x  -> 0   the worktree is judged
#     git -C <worktree> commit -m "a message"  -> 0
#     git -C <wt> add -A && git -C <wt> commit -m x && git -C <wt> push -> 0
#     git -C <fixture> -C feature push         -> 0   cumulative, arrives in <wt>
#     git -C <worktree> --git-dir=.git commit -m x -> 0  gitdir under the -C
#     git --git-dir=<worktree>/.git push       -> 0   a `.git` FILE is followed
#     git -C <a path that does not exist> push -> 0   nothing to judge
#     git --nonsense-flag -C <worktree> push   -> 2   option named in the refusal
#   And the mirror, from a session standing on `feat/x`:
#     git -C <the trunk, on main> push         -> 2   the trunk is judged
#     git -C <fixture> -C trunk commit -m x    -> 2   cumulative, lands on main
#     git -C <worktree> -C ../trunk commit -m x -> 2  relative, still cumulative
#     git --git-dir=<a worktree on `develop`>/.git commit -m x -> 2
#     git -C '<spaced path>' -C '<trunk>' commit -m x -> 2  two quoted -C paths
#     git --nonsense-flag status               -> 0   no write to hide
#   QUOTED SELECTORS ACROSS TWO SEGMENTS — recovery is line-global, so two
#   different quoted paths for one flag are refused wherever they sit, and two
#   identical ones are read. From a session standing on `feat/x`:
#     git -C '<trunk, on main>' commit -m x && git -C '<worktree>' status -> 2
#     git -C '<worktree>' commit -m x && git -C '<trunk>' status          -> 2
#     git -C '<worktree>' commit -m x && git -C '<worktree>' push         -> 0
#     git -C '<trunk>' commit -m x && git -C '<trunk>' push               -> 2
#   THE POLICY COMES FROM THE CHECKOUT THE BRANCH CAME FROM — a bare
#   `--git-dir` aimed at a linked worktree reads THAT worktree's
#   nen/workflow.json, not the primary checkout's. From a session on `main`,
#   against a worktree of the trunk standing on `b2` whose own checked-out
#   workflow.json declares `branch.base: b2`:
#     git --git-dir=<that worktree>/.git commit -m x -> 2   its own base is read
#     git --git-dir=<a worktree on feat/x>/.git commit -m x -> 0
#   MULTI-LINE COMMANDS AND HEREDOC BODIES — the payload writes a newline as the
#   escape `\n`, and both of these arrived as ONE line before step 1b. From a
#   session standing on `main` (cwd = the trunk):
#     SP=…\ncd <worktree>\ngit add -A && git commit -F $SP/m 2>&1 | tail -5 -> 0
#     cd <the trunk>\ngit commit -m x        (cwd = the worktree, on feat/x) -> 2
#     python3 - <<'PY'\n… | git push -u origin HEAD | …\nPY                  -> 0
#     cat > f <<EOF\ngit commit -m x\nEOF                                    -> 0
#     sh <<EOF\ngit commit -m x\nEOF                       -> 2  a shell RUNS it
#     printf '%s' 'a\ngit push -u origin HEAD\nb' > f      -> 0  one quoted span
#
# NO jq. Hatsu's installed path is one binary plus git and gh (README,
# 'On the installed plugin path'), so the JSON here is read with sed.

# `-f` for the whole run: a token like `*` reaches the parser as itself and is
# never expanded against the working directory.
set -uf

nl='
'
tab=$(printf '\t')
# Two control characters, used as placeholders while the payload's escapes are
# translated. Neither can occur in the payload: JSON escapes every control
# character below 0x20 inside a string, so a raw one never survives to here.
bs_mark=$(printf '\001')
nl_mark=$(printf '\002')

payload=$(cat 2>/dev/null || :)

# A JSON-escaped quote inside a value would stop the `[^"]*` extraction below
# and truncate the command — `git commit -m \"x\"` would read as `git commit -m
# \`, and `bash -c \"… git push\"` would lose its whole payload. In valid JSON
# `\"` occurs ONLY inside a string, so rewriting it to an apostrophe before
# extraction keeps the structure the parser needs (a quoted span stays a quoted
# span) and costs nothing this guard reads.
payload=$(printf '%s\n' "$payload" | sed 's/\\"/'\''/g')

json_str() {
  # $1 = text, $2 = key. First string value for that key.
  printf '%s\n' "$1" \
    | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1
}

recover_quoted() {
  # The value written after $2, for the case where masking replaced a quoted
  # span with `@`. $1 = the raw command line, $2 = the flag or word it follows;
  # the separator may be whitespace or `=`, so `-C '…'` and `--git-dir='…'` are
  # both read. The sed match is greedy, so this answers with the LAST such span
  # on the line — fine for `cd`, whose reading is unchanged, and NOT fine for a
  # repository-selecting flag, which goes through `recover_selector` below.
  found=$(printf '%s\n' "$1" | sed -n "s/.*$2[[:space:]=][[:space:]=]*'\([^']*\)'.*/\1/p" | head -n 1)
  [ -n "$found" ] || found=$(printf '%s\n' "$1" | sed -n "s/.*$2[[:space:]=][[:space:]=]*\"\([^\"]*\)\".*/\1/p" | head -n 1)
  printf '%s' "$found"
}

quoted_values() {
  # EVERY quoted value written after $2 on the raw line $1, one per line, in
  # argv order. `${rest#*"$2"}` strips the SHORTEST prefix, so this walks the
  # occurrences forwards; a single greedy `sed` match only ever finds the last
  # one, which belongs to a different segment as often as not.
  qv_rest=$1
  while :; do
    case "$qv_rest" in
      *"$2"*) qv_rest=${qv_rest#*"$2"} ;;
      *) return 0 ;;
    esac
    while :; do
      case "$qv_rest" in
        ' '*|'='*|"$tab"*) qv_rest=${qv_rest#?} ;;
        *) break ;;
      esac
    done
    case "$qv_rest" in
      "'"*)
        qv_body=${qv_rest#\'}
        case "$qv_body" in
          *"'"*) printf '%s\n' "${qv_body%%\'*}"; qv_rest=${qv_body#*\'} ;;
        esac ;;
      '"'*)
        qv_body=${qv_rest#\"}
        case "$qv_body" in
          *'"'*) printf '%s\n' "${qv_body%%\"*}"; qv_rest=${qv_body#*\"} ;;
        esac ;;
    esac
  done
}

selector_conflicts() {
  # True when the repository-selecting flag $1 is written with two DIFFERENT
  # quoted paths anywhere on the line. Recovery is line-GLOBAL: it cannot tell
  # the span this segment wrote from the span the next segment wrote, so
  # `git -C '<main>' commit -m x && git -C '<feat>' status` would otherwise
  # judge the commit against `<feat>` and allow a commit on the base. Two
  # different paths are exactly the case where an answer assembled from the
  # wrong half is worse than no answer; two identical ones are not ambiguous at
  # all and are read normally.
  #
  # It runs in THIS shell rather than inside a command substitution, because an
  # `exit` in a substitution leaves only the subshell — the refusal has to be
  # able to end the script.
  sc_first=""
  sc_seen=0
  while IFS= read -r sc_one; do
    [ -n "$sc_one" ] || continue
    if [ "$sc_seen" -eq 0 ]; then
      sc_first=$sc_one
      sc_seen=1
    elif [ "$sc_one" != "$sc_first" ]; then
      return 0
    fi
  done <<EOF
$(quoted_values "$command_line" "$1")
EOF
  return 1
}

mask_spanning_quotes() {
  # A quoted span that CONTAINS the escape `\n` is a MULTI-LINE string. It is
  # masked here, while the payload is still one line, because the per-line
  # masking of step 1d cannot see a span once that escape has become a real
  # newline — and a document quoted into a command would then have every one of
  # its lines parsed as a command of its own.
  printf '%s\n' "$1" | sed -e "s/'[^']*\\\\n[^']*'/@/g" -e 's/"[^"]*\\n[^"]*"/@/g'
}

unescape_newlines() {
  # The payload writes a newline as the two-character escape `\n`, and a
  # backslash the command genuinely contains as `\\`. Protect the second before
  # translating the first, or `tr ';|()&' '\n\n\n\n\n'` — an ordinary command,
  # and this script's own step 2 — would sprout newlines it never had.
  printf '%s\n' "$1" \
    | sed -e "s/\\\\\\\\/$bs_mark/g" -e "s/\\\\n/$nl_mark/g" -e "s/$bs_mark/\\\\\\\\/g" \
    | tr "$nl_mark" '\n'
}

unquote_heredoc_delims() {
  # `<<'EOF'` and `<<"EOF"` name the same delimiter as `<<EOF` — the quotes
  # decide whether the BODY is expanded, which is nothing to this guard. They
  # are removed before step 1d masks quoted spans, so that the opener survives
  # the masking and step 1e can still find the body. A `<<` that is itself
  # inside a quoted span (`echo "a << b"`) is masked away with its span and
  # opens nothing.
  printf '%s\n' "$1" \
    | sed -e "s/<<\\(-\\{0,1\\}\\)'\\([A-Za-z0-9_.:-]\\{1,\\}\\)'/<<\\1\\2/g" \
          -e 's/<<\(-\{0,1\}\)"\([A-Za-z0-9_.:-]\{1,\}\)"/<<\1\2/g'
}

heredoc_delimiters() {
  # Every heredoc delimiter opened on the line $1, one per line, in order.
  # `<<<` is a here-STRING — no body, no delimiter — and is stepped over.
  hd_rest=$1
  while :; do
    case "$hd_rest" in
      *'<<'*) hd_rest=${hd_rest#*<<} ;;
      *) return 0 ;;
    esac
    case "$hd_rest" in '<'*) hd_rest=${hd_rest#<}; continue ;; esac
    case "$hd_rest" in '-'*) hd_rest=${hd_rest#-} ;; esac
    while :; do
      case "$hd_rest" in ' '*|"$tab"*) hd_rest=${hd_rest#?} ;; *) break ;; esac
    done
    hd_word=""
    hd_scan=$hd_rest
    while :; do
      case "$hd_scan" in
        [A-Za-z0-9_.:-]*) hd_word="$hd_word${hd_scan%"${hd_scan#?}"}"; hd_scan=${hd_scan#?} ;;
        *) break ;;
      esac
    done
    [ -n "$hd_word" ] && printf '%s\n' "$hd_word"
  done
}

mask_heredoc_bodies() {
  # A heredoc body is what the command WRITES, not what it runs: a markdown
  # table quoting `git push -u origin HEAD` as evidence is a document, and this
  # guard refused a write of exactly that. Each body line becomes `@`.
  #
  # THE EXCEPTION IS A BODY A SHELL RUNS. `sh <<EOF`, `bash <<EOF`, `… | sh
  # <<EOF` execute what they are handed, so those bodies are kept and parsed
  # like any other line — the same reason step 0 unwraps `sh -c '<script>'`.
  hb_out=""
  hb_pending=""
  hb_shell=0
  while IFS= read -r hb_line; do
    if [ -n "$hb_pending" ]; then
      hb_first=${hb_pending%%"$nl"*}
      hb_trim=$hb_line
      while :; do
        case "$hb_trim" in
          ' '*|"$tab"*) hb_trim=${hb_trim#?} ;;
          *' '|*"$tab") hb_trim=${hb_trim%?} ;;
          *) break ;;
        esac
      done
      if [ "$hb_trim" = "$hb_first" ]; then
        # Pop the delimiter just closed. A `#*` on a list of one would answer
        # with the list itself, so the last one is emptied explicitly.
        case "$hb_pending" in
          *"$nl"*) hb_pending=${hb_pending#*"$nl"} ;;
          *) hb_pending=""; hb_shell=0 ;;
        esac
        hb_out="$hb_out$hb_line$nl"
        continue
      fi
      if [ "$hb_shell" -eq 1 ]; then hb_out="$hb_out$hb_line$nl"; else hb_out="$hb_out@$nl"; fi
      continue
    fi
    hb_out="$hb_out$hb_line$nl"
    case "$hb_line" in *'<<'*) ;; *) continue ;; esac
    hb_pending=$(heredoc_delimiters "$hb_line")
    [ -n "$hb_pending" ] || continue
    hb_shell=0
    for hb_t in $hb_line; do
      case "$hb_t" in
        sh|bash|zsh|dash|ksh|/bin/sh|/bin/bash|/bin/zsh) hb_shell=1; break ;;
      esac
    done
  done <<EOF
$1
EOF
  printf '%s' "$hb_out"
}

resolve() {
  # $1 = a path as written, $2 = the directory it is relative to.
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$2" "$1" ;;
  esac
}

refuse_unreadable() {
  # $1 = what could not be read.
  printf 'hatsu: refusing this command — %s, so the branch the write would land on cannot be established; run the git command directly, from inside the repository it targets.\n' \
    "$1" >&2
  exit 2
}

refuse_option() {
  # $1 = the global option the argv walk cannot follow.
  printf 'hatsu: refusing this command — it carries the git global option `%s`, which this guard does not know; an unknown option may or may not take the token after it, so neither the subcommand nor the directory git would run in can be established. Run the git command directly, from inside the repository it targets.\n' \
    "$1" >&2
  exit 2
}

command_line=$(json_str "$payload" command)
[ -n "$command_line" ] || exit 0

cwd=$(json_str "$payload" cwd)
[ -n "$cwd" ] || cwd=$PWD
[ -d "$cwd" ] || exit 0

# --- step 0: unwrap a shell wrapper -----------------------------------------
# `sh -c '<script>'` RUNS <script>. Left alone, masking would collapse the
# payload to `@` and the segment's first token would be `sh`, so the write
# inside it would never be seen. The payload is recovered and appended as its
# own segment; a wrapper whose payload cannot be recovered fails closed.
expanded=$command_line
case "$command_line" in
  *sh\ -c\ * | *sh\ -lc\ * | *sh\ -cx\ * )
    wrapped=$(recover_quoted "$command_line" "-c")
    if [ -n "$wrapped" ]; then
      expanded="$command_line ; $wrapped"
    else
      # Unreadable payload. Refuse only where there is something to refuse:
      # a line with no write token anywhere is not this guard's business, and
      # blocking every `bash -c $var` would block the session on a doubt.
      case "$command_line" in
        *commit* | *push*)
          refuse_unreadable "it runs a shell wrapper whose script this guard cannot read" ;;
      esac
    fi
    ;;
esac

# --- step 1: quoted spans, real newlines, heredoc bodies --------------------
# 1a. Multi-line quoted spans, masked while the payload is still one line.
masked=$(mask_spanning_quotes "$expanded")
# 1b. The payload's `\n` escapes become real newlines, so a `cd` on its own line
#     moves the directory every line under it writes in.
masked=$(unescape_newlines "$masked")
# 1c. `<<'EOF'` -> `<<EOF`, so the opener survives 1d.
masked=$(unquote_heredoc_delims "$masked")
# 1d. The remaining quoted spans, per line. Single-quoted first: a `'` inside a
#     double-quoted span has no partner and so matches nothing, while a `"`
#     inside a single-quoted span would.
masked=$(printf '%s\n' "$masked" | sed -e "s/'[^']*'/@/g" -e 's/"[^"]*"/@/g')
# 1e. Heredoc bodies — data, unless a shell is the one being handed them.
masked=$(mask_heredoc_bodies "$masked")

# --- step 2: split into segments --------------------------------------------
# The `tr` turns each shell operator into a newline; the newlines 1b produced are
# already separators, so every line of a multi-line command is its own segment.
segments=$(printf '%s\n' "$masked" | tr ';|()&`' '\n\n\n\n\n\n')

# --- step 3: the git argv walk ----------------------------------------------
# Sets `is_git`, `sub` (the subcommand, empty when the walk found none),
# `unfollowable` (a global option not on the list below), and the
# repository-selecting options the segment carried. `cdirs` holds EVERY `-C`
# value, newline-separated and in argv order, because git applies them
# cumulatively — `git -C a -C b` runs in `a/b`, not in `b`.
is_git=0
sub=""
cdirs=""
gitdir=""
worktree=""
unfollowable=""
parse_git_segment() {
  is_git=0
  sub=""
  cdirs=""
  gitdir=""
  worktree=""
  unfollowable=""
  # shellcheck disable=SC2086  # deliberate word split; globbing is off (set -f)
  set -- $1
  [ "${1:-}" = "git" ] || return 0
  is_git=1
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)            cdirs="$cdirs${2:-}$nl";       shift 2 2>/dev/null || return 0 ;;
      --git-dir)     gitdir=${2:-};                 shift 2 2>/dev/null || return 0 ;;
      --work-tree)   worktree=${2:-};               shift 2 2>/dev/null || return 0 ;;
      --git-dir=*)   gitdir=${1#--git-dir=};        shift ;;
      --work-tree=*) worktree=${1#--work-tree=};    shift ;;
      -c|--namespace|--super-prefix|--attr-source|--config-env)
                     shift 2 2>/dev/null || return 0 ;;
      # The `--key=value` spellings of the value-taking options, and the ones
      # that never take a value. Both are safe to step over: neither can hide
      # the following token.
      --namespace=*|--super-prefix=*|--attr-source=*|--config-env=*|--exec-path=*|--list-cmds=*)
                     shift ;;
      -v|--version|-h|--help|-p|-P|--paginate|--no-pager|--bare|--exec-path|\
      --html-path|--man-path|--info-path|--no-replace-objects|--no-lazy-fetch|\
      --no-optional-locks|--no-advice|--literal-pathspecs|--glob-pathspecs|\
      --noglob-pathspecs|--icase-pathspecs|--)
                     shift ;;
      # Anything else that looks like an option is NOT stepped over. Whether it
      # takes the next token is what decides where the subcommand is, and a
      # guess either way can hide a write or judge the wrong directory.
      -*)            unfollowable=$1; return 0 ;;
      *)             sub=$1; return 0 ;;
    esac
  done
}

has_write_token() {
  # $1 = a masked segment. True when `commit` or `push` appears as a WHOLE
  # token anywhere in it — used only to decide whether an unresolvable git
  # segment must fail closed.
  for t in $1; do
    case "$t" in commit|push) return 0 ;; esac
  done
  return 1
}

# --- pass 1: what is in this line -------------------------------------------
writes=0
changes_branch=0
act="git commit"
here=$cwd

while IFS= read -r seg; do
  [ -n "$seg" ] || continue
  # shellcheck disable=SC2086  # deliberate word split; globbing is off (set -f)
  set -- $seg
  if [ "${1:-}" = "cd" ] && [ -n "${2:-}" ]; then
    moved=$2
    [ "$moved" = "@" ] && moved=$(recover_quoted "$command_line" cd)
    case "$moved" in
      -|@|-*) : ;;                       # `cd -`, or a path this guard cannot read
      *) here=$(resolve "$moved" "$here") ;;
    esac
    continue
  fi
  parse_git_segment "$seg"
  [ "$is_git" -eq 1 ] || continue
  if [ -n "$unfollowable" ]; then
    # An option the walk cannot follow. Refuse only where there is a write to
    # hide behind it — `git --weird status` is not this guard's business.
    if has_write_token "$seg"; then
      refuse_option "$unfollowable"
    fi
    continue
  fi
  case "$sub" in
    commit|push)
      writes=$((writes + 1))
      act="git $sub"
      ;;
    switch|checkout)
      changes_branch=1
      ;;
    branch)
      case " $seg " in
        *" -f "* | *" -m "* | *" -M "* | *" --force "* | *" --move "*) changes_branch=1 ;;
      esac
      ;;
    *)
      # A git segment whose subcommand the walk could not establish, yet which
      # carries a write token: an option form this guard does not know may be
      # standing between `git` and `commit`. Refuse rather than wave it past.
      if has_write_token "$seg"; then
        refuse_unreadable "a git command in it carries a write but no subcommand this guard can identify"
      fi
      ;;
  esac
done <<EOF
$segments
EOF

[ "$writes" -gt 0 ] || exit 0

# --- fail closed: branch change and write on the same line -------------------
if [ "$changes_branch" -eq 1 ]; then
  printf 'hatsu: refusing a compound command that changes branch and writes; run them separately. The branch this guard can see is the one you are on now, not the one %s would land on, so the base-branch check would be answered by the wrong repository state.\n' \
    "$act" >&2
  exit 2
fi

# --- pass 2: the branch comparison, once per write --------------------------
here=$cwd

while IFS= read -r seg; do
  [ -n "$seg" ] || continue
  # shellcheck disable=SC2086  # deliberate word split; globbing is off (set -f)
  set -- $seg
  if [ "${1:-}" = "cd" ] && [ -n "${2:-}" ]; then
    moved=$2
    [ "$moved" = "@" ] && moved=$(recover_quoted "$command_line" cd)
    case "$moved" in
      -|@|-*) : ;;
      *) here=$(resolve "$moved" "$here") ;;
    esac
    continue
  fi
  parse_git_segment "$seg"
  case "$sub" in commit|push) ;; *) continue ;; esac

  # Every `-C`, in order, each resolved against the one before it — git's own
  # cumulative rule. THIS is the directory the command runs in, and therefore
  # the checkout whose branch decides the refusal; the session's own cwd is only
  # the starting point a `-C` moves away from.
  cbase=$here
  while IFS= read -r one; do
    [ -n "$one" ] || continue
    if [ "$one" = "@" ]; then
      # A quoted path, masked in step 1. It is read only when every quoted `-C`
      # on the LINE agrees — a second, different one, whether on this segment or
      # on another, fails closed rather than being assembled into a path that
      # belongs to neither.
      selector_conflicts -C && refuse_unreadable "it writes more than one different quoted \`-C\` path, and this guard cannot tell which segment each of them belongs to"
      one=$(recover_quoted "$command_line" -C)
      [ -n "$one" ] || refuse_unreadable "its \`-C\` path is quoted in a form this guard cannot read"
    fi
    cbase=$(resolve "$one" "$cbase")
  done <<EOF
$cdirs
EOF

  # A repository-selecting path masked to `@` was quoted; recover it or refuse.
  if [ "$gitdir" = "@" ]; then
    selector_conflicts --git-dir && refuse_unreadable "it writes more than one different quoted \`--git-dir\` path, and this guard cannot tell which segment each of them belongs to"
    gitdir=$(recover_quoted "$command_line" --git-dir)
    [ -n "$gitdir" ] || refuse_unreadable "its \`--git-dir\` path is quoted in a form this guard cannot read"
  fi
  if [ "$worktree" = "@" ]; then
    selector_conflicts --work-tree && refuse_unreadable "it writes more than one different quoted \`--work-tree\` path, and this guard cannot tell which segment each of them belongs to"
    worktree=$(recover_quoted "$command_line" --work-tree)
    [ -n "$worktree" ] || refuse_unreadable "its \`--work-tree\` path is quoted in a form this guard cannot read"
  fi

  # `--git-dir` and `--work-tree` are resolved against `cbase` — the directory
  # the `-C` chain arrived at — because git applies every `-C` before either.
  branch=""
  root=""
  if [ -n "$gitdir" ]; then
    gd=$(resolve "$gitdir" "$cbase")
    # `-e`, not `-d`: a LINKED WORKTREE's `.git` is a FILE holding `gitdir: …`,
    # and git follows it. Testing for a directory made every `--git-dir` aimed
    # at a worktree unjudged, which is the shape this guard exists for.
    [ -e "$gd" ] || continue
    if [ -n "$worktree" ]; then
      wt=$(resolve "$worktree" "$cbase")
      branch=$(git --git-dir="$gd" --work-tree="$wt" branch --show-current 2>/dev/null || :)
      root=$wt
    else
      branch=$(git --git-dir="$gd" branch --show-current 2>/dev/null || :)
      # THE POLICY COMES FROM THE CHECKOUT THE BRANCH CAME FROM. With no work
      # tree given, `rev-parse --show-toplevel` answers about the CWD rather
      # than about `--git-dir`, so it cannot be used here — but git will still
      # say which git dir it resolved: for a LINKED WORKTREE that is
      # `<common>/worktrees/<name>`, and the `gitdir` file sitting there holds
      # the path of that worktree's own `.git` FILE, whose directory is the
      # checkout. Falling back to the common dir's parent instead would read the
      # PRIMARY checkout's nen/workflow.json — a different working tree, which
      # may have a different `branch.base` checked out, and then the branch just
      # read from the worktree is compared against a base nobody declared for it.
      resolved=$(git --git-dir="$gd" rev-parse --path-format=absolute --git-dir 2>/dev/null || :)
      case "$resolved" in
        */worktrees/*)
          link=$(cat "$resolved/gitdir" 2>/dev/null || :)
          if [ -n "$link" ]; then root=$(dirname "$link"); fi
          ;;
      esac
      if [ -z "$root" ]; then
        common=$(git --git-dir="$gd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || :)
        case "$common" in
          /*) root=$(dirname "$common") ;;
          *)  root=$(dirname "$gd") ;;
        esac
      fi
    fi
  else
    target=$cbase
    [ -n "$worktree" ] && target=$(resolve "$worktree" "$cbase")
    [ -d "$target" ] || continue
    branch=$(git -C "$target" branch --show-current 2>/dev/null || :)
    root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || :)
  fi

  # Empty means a detached HEAD or not a repository at all — neither is this
  # guard's business.
  [ -n "$branch" ] || continue

  base="main"
  if [ -n "$root" ] && [ -f "$root/nen/workflow.json" ]; then
    declared=$(sed -n 's/.*"base"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$root/nen/workflow.json" | head -n 1)
    [ -n "$declared" ] && base=$declared
  fi

  [ "$branch" = "$base" ] || continue

  printf 'hatsu: refusing %s on %s — %s is the workflow base (nen/workflow.json branch.base) and is only ever reached through a merged PR; cut {model}/{persona}/{descriptor} with the breath skill (nen shu warmup --repo <path> --branch <name>) and commit there.\n' \
    "git $sub" "$base" "$base" >&2
  exit 2
done <<EOF
$segments
EOF

exit 0
