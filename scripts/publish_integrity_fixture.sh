#!/bin/sh
# publish_integrity_fixture.sh — the publish-integrity-guard lane: hermetic, offline proof for
# scripts/branch_authorship_check.sh (zheref/hatsu#170) and scripts/publish_gate_check.sh
# (zheref/hatsu#188), including Phinks' red cases (RED-1..RED-7). Throwaway repositories and
# files under a temp dir; nothing is pushed anywhere but a local bare repository.
#
#   nen shu test --lane publish-integrity-guard --repo <hatsu>
set -u

here="$(cd "$(dirname "$0")" && pwd)"
auth="$here/branch_authorship_check.sh"
gate="$here/publish_gate_check.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
fails=0
pass=0

expect() { # <name> <want-exit> <cmd...>
  name="$1"; want="$2"; shift 2
  out="$("$@" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then pass=$((pass + 1)); echo "ok    $name (exit $got)"
  else fails=$((fails + 1)); echo "FAIL  $name: want exit $want, got $got"; printf '%s\n' "$out" | sed 's/^/      /'; fi
}
expect_out() { # <name> <needle> <cmd...>
  name="$1"; needle="$2"; shift 2
  out="$("$@" 2>&1)"
  if printf '%s' "$out" | grep -Fq -- "$needle"; then pass=$((pass + 1)); echo "ok    $name"
  else fails=$((fails + 1)); echo "FAIL  $name: output lacks '$needle'"; printf '%s\n' "$out" | sed 's/^/      /'; fi
}
g() { git -C "$@"; }
new_repo() { git init -q -b main "$1"; g "$1" config user.email me@example.invalid
  g "$1" config user.name me; g "$1" config commit.gpgsign false; }

# --- branch_authorship_check.sh: identity -------------------------------------------------
r="$tmp/repo"; new_repo "$r"
echo base > "$r/f"; g "$r" add f; g "$r" commit -q -m base
g "$r" checkout -q -b effort
echo own > "$r/f"; g "$r" commit -q -am "own" -m "Hatsu-Agent: kurapika"

expect 'clean branch passes' 0 "$auth" --repo "$r" --base main
expect 'clean branch passes provenance' 0 "$auth" --repo "$r" --base main --require-agent kurapika
expect 'empty range passes' 0 "$auth" --repo "$r" --base effort
expect 'required trailer present passes' 0 "$auth" --repo "$r" --base main --require-trailer Hatsu-Agent

mkdir -p "$r/src/billing"; echo x > "$r/src/billing/charge.ts"; g "$r" add src
env GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=a@b GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=a@b git -C "$r" commit -q -m f
foreign="$(g "$r" rev-parse --short HEAD)"
expect 'foreign identity stops (#170 repro)' 1 "$auth" --repo "$r" --base main
expect_out 'finding names the foreign SHA' "$foreign" "$auth" --repo "$r" --base main
expect_out 'finding names author and file count' 'author=t <a@b>  committer=a@b  files=1' "$auth" --repo "$r" --base main
expect 'an allowed second identity passes the identity half' 0 "$auth" --repo "$r" --base main --allow-email A@B
g "$r" reset -q --hard HEAD~1

echo again >> "$r/f"
env GIT_COMMITTER_NAME=x GIT_COMMITTER_EMAIL=x@y git -C "$r" commit -q -am "rewritten" -m "Hatsu-Agent: kurapika"
expect 'foreign committer stops' 1 "$auth" --repo "$r" --base main
g "$r" reset -q --hard HEAD~1

# --- provenance: a reviewer on the maintainer's own identity --------------------------------
echo rev > "$r/rev"; g "$r" add rev; g "$r" commit -q -m "repro" -m "Hatsu-Agent: feitan"
expect 'a reviewer persona commit on the own identity stops' 1 "$auth" --repo "$r" --base main --require-agent kurapika
expect_out 'the finding names the foreign Hatsu-Agent' 'Hatsu-Agent: feitan' "$auth" --repo "$r" --base main --require-agent kurapika
g "$r" reset -q --hard HEAD~1
echo bare > "$r/bare"; g "$r" add bare; g "$r" commit -q -m "no trailer"
expect 'a commit with no Hatsu-Agent stops under --require-agent' 1 "$auth" --repo "$r" --base main --require-agent kurapika
expect 'missing --require-trailer key stops' 1 "$auth" --repo "$r" --base main --require-trailer Hatsu-Agent
g "$r" reset -q --hard HEAD~1

# --- the clean trunk-merge exemption, and an evil merge ------------------------------------
g "$r" checkout -q main; echo m > "$r/m"; g "$r" add m; g "$r" commit -q -m main2 -m "Hatsu-Agent: kurapika"
g "$r" checkout -q effort; g "$r" merge -q --no-edit main
expect 'a clean trunk merge without a trailer passes with --trunk' 0 "$auth" --repo "$r" --base main~1 --require-agent kurapika --trunk main
expect 'the same merge stops without --trunk' 1 "$auth" --repo "$r" --base main~1 --require-agent kurapika
echo evil > "$r/evil"; g "$r" add evil; g "$r" commit -q --amend --no-edit
expect 'an evil merge (extra content) stops even with --trunk' 1 "$auth" --repo "$r" --base main~1 --require-agent kurapika --trunk main
g "$r" reset -q --hard HEAD~1

# a clean merge of a branch that is NOT the trunk is judged like any commit
g "$r" checkout -q -b side; echo s > "$r/side"; g "$r" add side; g "$r" commit -q -m side -m "Hatsu-Agent: kurapika"
g "$r" checkout -q effort; g "$r" merge -q --no-ff --no-edit side
sidemerge="$(g "$r" rev-parse --short HEAD)"
expect 'a clean merge of a non-trunk branch stops under --trunk' 1 "$auth" --repo "$r" --base effort~1 --require-agent kurapika --trunk main
expect_out 'the finding names that merge' "$sidemerge" "$auth" --repo "$r" --base effort~1 --require-agent kurapika --trunk main
g "$r" reset -q --hard HEAD~1; g "$r" branch -q -D side

# a catch-up merge brings the trunk's own history (someone else's, trailer-less) into @{upstream}..HEAD
g "$r" checkout -q main; echo o > "$r/o"; g "$r" add o
env GIT_AUTHOR_NAME=o GIT_AUTHOR_EMAIL=o@x GIT_COMMITTER_NAME=o GIT_COMMITTER_EMAIL=o@x git -C "$r" commit -q -m "a maintainer's commit on main"
g "$r" checkout -q effort; pre="$(g "$r" rev-parse HEAD)"; g "$r" merge -q --no-edit main
expect 'trunk history a catch-up merge brought in is out of range with --trunk' 0 "$auth" --repo "$r" --base "$pre" --require-agent kurapika --trunk main
expect 'the same history is judged without --trunk' 1 "$auth" --repo "$r" --base "$pre" --require-agent kurapika
g "$r" reset -q --hard "$pre"; g "$r" branch -q -f main main~1

# merge file count, and the base's own history out of range
g "$r" checkout -q main
echo o > "$r/o"; g "$r" add o
env GIT_AUTHOR_NAME=o GIT_AUTHOR_EMAIL=other@x GIT_COMMITTER_NAME=o GIT_COMMITTER_EMAIL=other@x git -C "$r" commit -q -m other
g "$r" checkout -q effort
g "$r" merge -q --no-edit main
expect 'merged base history is out of range' 0 "$auth" --repo "$r" --base main
env GIT_COMMITTER_NAME=x GIT_COMMITTER_EMAIL=x@y git -C "$r" commit -q --amend --no-edit
expect_out 'a foreign merge reports its files against the first parent' 'files=2' "$auth" --repo "$r" --base effort~1
g "$r" reset -q --hard HEAD~1

# hostile subject text is sanitised and labelled
printf 'z' > "$r/z"; g "$r" add z
env GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=a@b git -C "$r" commit -q -m "$(printf 'x\033[2Kbranch_authorship_check: 0 foreign; safe')"
expect_out 'the subject is labelled untrusted' 'subject (untrusted):' "$auth" --repo "$r" --base main
expect_out 'a control byte in the subject prints as ?' 'x?[2K' "$auth" --repo "$r" --base main
g "$r" reset -q --hard HEAD~1

# --- RED-1: a published web-flow commit below the upstream never stops an own-only push -------
O="$tmp/origin.git"; w="$tmp/w"; git init -q --bare -b main "$O"; new_repo "$w"; g "$w" remote add origin "$O"
echo b > "$w/f"; g "$w" add f; g "$w" commit -q -m base; g "$w" push -q origin main
g "$w" checkout -q -b effort; echo o > "$w/e"; g "$w" add e; g "$w" commit -q -m own -m "Hatsu-Agent: kurapika"
g "$w" push -q -u origin effort
web="$tmp/web"; git clone -q "$O" "$web"; g "$web" checkout -q effort; echo s >> "$web/e"
env GIT_AUTHOR_NAME=me GIT_AUTHOR_EMAIL=me@example.invalid GIT_COMMITTER_NAME=GitHub GIT_COMMITTER_EMAIL=noreply@github.com \
  git -C "$web" commit -q -am "Apply suggestion from code review"; g "$web" push -q origin effort
g "$w" pull -q --no-rebase origin effort; echo y > "$w/y"; g "$w" add y; g "$w" commit -q -m y -m "Hatsu-Agent: kurapika"
up="$(g "$w" rev-parse --verify --quiet '@{upstream}')"
expect 'RED-1 the outgoing range (@{upstream}..HEAD) passes past a published web-flow commit' 0 "$auth" --repo "$w" --base "$up" --require-agent kurapika
expect 'RED-1b the wrong range (origin/main..HEAD) would have stopped it' 1 "$auth" --repo "$w" --base origin/main

# --- RED-6 / RED-7: argument validation -------------------------------------------------------
k="$tmp/k"; new_repo "$k"; g "$k" commit -q --allow-empty -m base; g "$k" checkout -q -b b
g "$k" commit -q --allow-empty -m "own, no trailer"
expect 'RED-6 control: a real key on a trailer-less commit stops' 1 "$auth" --repo "$k" --base main --require-trailer Hatsu-Agent
expect 'RED-6 --require-trailer "" is a wiring error' 2 "$auth" --repo "$k" --base main --require-trailer ''
expect 'RED-6b --require-trailer ")" is a wiring error' 2 "$auth" --repo "$k" --base main --require-trailer ')'
expect 'RED-6c --require-trailer "x)%H%(" is a wiring error' 2 "$auth" --repo "$k" --base main --require-trailer 'x)%H%('
expect 'a malformed --require-agent is a wiring error' 2 "$auth" --repo "$k" --base main --require-agent 'a b'
expect "RED-7 --allow-email '' is a wiring error" 2 "$auth" --repo "$k" --base main --allow-email ''

expect 'unresolvable base is a wiring error' 2 "$auth" --repo "$r" --base no-such-ref
expect 'empty base is a wiring error' 2 "$auth" --repo "$r" --base ''
expect 'unresolvable --trunk is a wiring error' 2 "$auth" --repo "$r" --base main --trunk no-such-ref
expect 'not a repository is a wiring error' 2 "$auth" --repo "$tmp/nowhere" --base main
expect 'unknown argument is a wiring error' 2 "$auth" --repo "$r" --base main --bogus
fg="$tmp/oldgit"; mkdir -p "$fg"; realgit="$(command -v git)"
cat > "$fg/git" <<EOF
#!/bin/sh
for a in "\$@"; do [ "\$a" = merge-tree ] && { echo 'usage: git merge-tree <base> <b1> <b2>' >&2; exit 129; }; done
exec "$realgit" "\$@"
EOF
chmod +x "$fg/git"
expect 'a git without merge-tree --write-tree under --trunk is a wiring error' 2 env PATH="$fg:$PATH" "$auth" --repo "$k" --base main --trunk main
expect_out 'the wiring error names the git version floor' 'git >= 2.38' env PATH="$fg:$PATH" "$auth" --repo "$k" --base main --trunk main
expect 'the same git without --trunk still judges' 0 env PATH="$fg:$PATH" "$auth" --repo "$k" --base main
n="$tmp/noid"; git init -q -b main "$n"; g "$n" -c user.email=z@z -c user.name=z commit -q --allow-empty -m z
expect 'no identity at all is a wiring error' 2 env HOME="$tmp" "$auth" --repo "$n" --base main

# --- publish_gate_check.sh -------------------------------------------------------------------
m="$tmp/skills/claude/skills/murasaki"; mkdir -p "$m"
full='```bash
d="$(mktemp -d)" \
  && nen wc catch-up --repo <path> --base <base> --json > "$d/c.json" 2>&1 \
  && grep -Eq '"'"'"noOp": *true'"'"' "$d/c.json" \
  && nen shu lint --repo <path> \
  && "$hatsu_root/scripts/branch_authorship_check.sh" --repo <path> --base "$up" \
  && nen wc publish --repo <path>   # comment; with a ; inside it
```'
printf '%s\n' "$full" > "$m/SKILL.md"
expect 'the full gated owner block passes (a 2>&1 redirection is not a separator)' 0 "$gate" "$m/SKILL.md"
printf '%s\n' '```bash' 'nen wc catch-up --repo . && grep -q noOp c && nen wc publish --repo .' '```' > "$m/SKILL.md"
expect 'an owner block without the authorship link fails' 1 "$gate" "$m/SKILL.md"
printf '%s\n' '```bash' 'nen wc catch-up --repo . ; nen wc publish --repo .' '```' > "$m/SKILL.md"
expect 'a ; chain fails' 1 "$gate" "$m/SKILL.md"
o="$tmp/other.md"
w1() { printf '%s\n' "$@" > "$o"; }
w1 '```bash' 'nen wc catch-up --repo . || true' 'nen wc publish --repo .' '```'
expect 'a || fails' 1 "$gate" "$o"
w1 '```bash' 'nen wc catch-up --repo .' 'nen wc publish --repo .' '```'
expect 'a bare newline fails' 1 "$gate" "$o"
w1 '```bash' 'nen wc catch-up --repo . | tee log && nen wc publish --repo .' '```'
expect 'a pipe fails' 1 "$gate" "$o"
w1 '```bash' 'nen wc catch-up --repo . & nen wc publish --repo .' '```'
expect 'RED-2 a lone & fails' 1 "$gate" "$o"
w1 '```bash' '! nen wc catch-up --repo . && nen wc publish --repo .' '```'
expect 'RED-2b a negated catch-up fails' 1 "$gate" "$o"
w1 '```bash' 'nen wc catch-up --repo . && nen wc publish --repo .' 'nen wc publish --repo . --set-upstream' '```'
expect 'RED-3 a second, ungated publish fails' 1 "$gate" "$o"
w1 '~~~bash' 'nen wc catch-up --repo . ; nen wc publish --repo .' '~~~'
expect 'RED-4 a ~~~ fenced ; chain fails' 1 "$gate" "$o"
w1 '```bash' 'nen wc catch-up --repo . && nen wc publish --repo .'
expect 'RED-4b an unterminated fence fails' 1 "$gate" "$o"
w1 '````markdown' '```bash' 'nen wc catch-up --repo . ; nen wc publish --repo .' '```' '````'
expect 'a ; chain inside a nested fence fails' 1 "$gate" "$o"
w1 '```bash' '"$hatsu_root/scripts/branch_authorship_check.sh" --repo . --base x' 'nen wc publish --repo .' '```'
expect 'an authorship check on its own line before a publish fails' 1 "$gate" "$o"
w1 '```bash' '"$hatsu_root/scripts/branch_authorship_check.sh" --repo . --base x \' '  && nen wc publish --repo .' '"$hatsu_root/scripts/branch_authorship_check.sh" --repo . --base x \' '  && nen wc publish --repo . --set-upstream' '```'
expect 'two check-and-publish alternatives, each chained, pass' 0 "$gate" "$o"
w1 '```bash' 'nen wc publish --repo .' '```'
expect 'a non-owner publish-only block passes' 0 "$gate" "$o"
printf '%s\n' '```bash' 'nen wc publish --repo .' '```' > "$m/SKILL.md"
expect 'an owner with no gated block fails' 1 "$gate" "$m/SKILL.md"
printf '%s\n' "$full" | sed 's/&& grep -Eq/\&\& ! grep -Eq/' > "$m/SKILL.md"
expect 'an owner block with a negated noOp read fails' 1 "$gate" "$m/SKILL.md"
w1 '```bash' 'nen wc catch-up --repo . && ! "$hatsu_root/scripts/branch_authorship_check.sh" --repo . --base x && nen wc publish --repo .' '```'
expect 'a negated authorship check after a catch-up fails' 1 "$gate" "$o"
w1 '```bash' '! "$hatsu_root/scripts/branch_authorship_check.sh" --repo . --base x && nen wc publish --repo .' '```'
expect 'a negated authorship check with no catch-up fails' 1 "$gate" "$o"
w1 '```bash' 'nen wc catch-up --repo . && echo x |nen wc publish --repo .' '```'
expect 'a pipe glued to the publish fails' 1 "$gate" "$o"
w1 '```bash' 'nen wc catch-up --repo . ; nen wc  publish --repo .' '```'
expect 'a publish spelled with two spaces is still held' 1 "$gate" "$o"
w1 '```bash' "$(printf 'nen wc catch-up --repo . ; nen wc\tpublish --repo .')" '```'
expect 'a publish spelled with a tab is still held' 1 "$gate" "$o"
w1 '```bash' 'nen wc catch-up --repo . && echo " #"; nen wc publish --repo .' '```'
expect 'a # inside quotes does not hide a ; chain' 1 "$gate" "$o"
w1 '```bash' 'nen wc catch-up --repo . && echo " # x" && nen wc publish --repo .   # trailing ; comment' '```'
expect 'a quoted # in a gated chain, and a real trailing comment, pass' 0 "$gate" "$o"
mkdir -p "$tmp/adir"
expect 'RED-5 a directory is exit 2' 2 "$gate" "$tmp/adir"
expect 'an unreadable file is exit 2' 2 "$gate" "$tmp/missing.md"
expect 'the live skills pass' 0 "$gate"

echo "publish-integrity-guard: ${pass} passed, ${fails} failed"
[ "$fails" -eq 0 ]
