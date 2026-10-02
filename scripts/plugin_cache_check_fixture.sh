#!/usr/bin/env bash
# plugin_cache_check_fixture.sh — hermetic cases for scripts/plugin_cache_check.sh (zheref/hatsu#122).
# Builds a throwaway source root and copies under a temp dir, runs from that temp dir (so the caller's
# own checkout is never read as an independent source), with HATSU_PLUGIN_ROOT unset and
# CLAUDE_CONFIG_DIR pointed at a fake config. Lane: plugin-cache-guard (nen/contract.json).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
check="$here/plugin_cache_check.sh"
work="$(mktemp -d)"; trap 'chmod -R u+rw "$work" 2>/dev/null; rm -rf "$work"' EXIT
work="$(cd "$work" && pwd -P)"
cd "$work" || exit 2
unset HATSU_PLUGIN_ROOT
cfg="$work/cfg"; mkdir -p "$cfg/plugins"
export CLAUDE_CONFIG_DIR="$cfg"
pass=0 fail=0
ok() { pass=$((pass+1)); echo "ok    $1"; }
bad() { fail=$((fail+1)); echo "FAIL  $1"; }
# every run is bounded: a check that opened a FIFO would hang, never pass
run() { out="$(perl -e 'alarm 20; exec @ARGV' bash "$check" "$@" 2>&1)"; rc=$?; }
expect() { local want="$1" name="$2"; shift 2; run "$@"; [ "$rc" -eq "$want" ] && ok "$name" || bad "$name: exit $rc, wanted $want -- $out"; }
has() { printf '%s' "$out" | grep -qF -- "$1" && ok "$2" || bad "$2 -- $out"; }
hasnt() { printf '%s' "$out" | grep -qF -- "$1" && bad "$2 -- $out" || ok "$2"; }
gitify() { git init -q "$1" && git -C "$1" symbolic-ref HEAD refs/heads/main && git -C "$1" add -A && git -C "$1" -c user.name=t -c user.email=t@example.invalid commit -qm init; }
record() { printf '%s\n' "$1" > "$cfg/plugins/installed_plugins.json"; }
clear_cfg() { rm -rf "$cfg"; mkdir -p "$cfg/plugins"; }

src="$work/src"
mkdir -p "$src/.claude-plugin" "$src/claude/skills/ten" "$src/claude/agents" "$src/claude/rules" "$src/hooks" "$src/templates" "$src/contracts" "$src/scripts" "$src/docs"
printf '{"name":"hatsu","version":"1.2.0"}\n' > "$src/.claude-plugin/plugin.json"
printf '{"name":"hatsu","plugins":[]}\n' > "$src/.claude-plugin/marketplace.json"
printf 'ten\n' > "$src/claude/skills/ten/SKILL.md"
printf 'kurapika\n' > "$src/claude/agents/kurapika.md"
printf 'rules\n' > "$src/claude/rules/hatsu.md"
printf '{}\n' > "$src/hooks/hooks.json"
printf 'body\n' > "$src/templates/pr-body.md"
printf '{}\n' > "$src/contracts/permissions.json"
printf '#!/bin/sh\n' > "$src/scripts/guard.sh"
printf 'not shipped\n' > "$src/docs/README.md"
fresh() { rm -rf "$work/$1"; cp -R "$src" "$work/$1"; rm -rf "$work/$1/.git"; }
fresh plain   # a pristine non-git copy of the source, taken before the source becomes a git checkout
gitify "$src"

fresh same
expect 0 "an identical copy reads identical" --root "$src" --cache "$work/same"
has "identical" "the verdict says identical"

fresh drift; printf 'ten, edited\n' > "$work/drift/claude/skills/ten/SKILL.md"
expect 1 "a same-version copy with different bytes is different" --root "$src" --cache "$work/drift"
has "differs:        claude/skills/ten/SKILL.md" "the differing path is named"

fresh extra; printf 'old skill\n' > "$work/extra/claude/agents/gone.md"
expect 1 "a file only in the cache is different" --root "$src" --cache "$work/extra"
has "only in cache:  claude/agents/gone.md" "the extra path is named"

fresh missing; rm "$work/missing/hooks/hooks.json"
expect 1 "a file missing from the cache is different" --root "$src" --cache "$work/missing"
has "only in source: hooks/hooks.json" "the missing path is named"

fresh manifest; printf '{"name":"hatsu","version":"1.1.0"}\n' > "$work/manifest/.claude-plugin/plugin.json"
expect 1 "a different manifest is different" --root "$src" --cache "$work/manifest"
has "plugin 1.1.0" "both versions are printed"

# Copilot (#212): a copy whose manifest names another plugin is not Hatsu -- never judged as drift
fresh othername; printf '{"name":"otherplug","version":"1.0.0"}\n' > "$work/othername/.claude-plugin/plugin.json"
expect 2 "an explicit cache naming another plugin is wiring, never drift" --root "$src" --cache "$work/othername"
has "is not a Hatsu copy" "the identity refusal is named"
hasnt "refresh it" "no refresh instruction for a non-Hatsu copy"

fresh mktjson; printf '{"name":"hatsu","plugins":[{}]}\n' > "$work/mktjson/.claude-plugin/marketplace.json"
expect 1 "a different marketplace.json is different" --root "$src" --cache "$work/mktjson"
has "differs:        .claude-plugin/marketplace.json" "marketplace.json is compared"

fresh stalescripts; printf '#!/bin/sh\nexit 1\n' > "$work/stalescripts/scripts/guard.sh"
expect 1 "a stale shipped script is different" --root "$src" --cache "$work/stalescripts"
has "differs:        scripts/guard.sh" "scripts/ is compared"

fresh unshipped; printf 'changed\n' > "$work/unshipped/docs/README.md"
expect 0 "a tree the plugin does not ship is not compared" --root "$src" --cache "$work/unshipped"

fresh dsstore; printf 'x' > "$work/dsstore/claude/skills/.DS_Store"
expect 0 ".DS_Store is ignored" --root "$src" --cache "$work/dsstore"

# symlinks are never opened (Feitan): a FIFO behind one would hang a check that opened it
fresh fifo; mkfifo "$work/pipe"; rm "$work/fifo/claude/rules/hatsu.md"; ln -s "$work/pipe" "$work/fifo/claude/rules/hatsu.md"
# run in the background; a check that opened the FIFO is released (a writer opens and closes it, so
# the reader sees EOF) and the case fails -- an alarm alone would leave the reader holding the pipe
( bash "$check" --root "$src" --cache "$work/fifo" > "$work/fifo.out" 2>&1; echo "$?" > "$work/fifo.rc" ) &
i=0; while [ ! -s "$work/fifo.rc" ] && [ "$i" -lt 100 ]; do sleep 0.2; i=$((i+1)); done
if [ ! -s "$work/fifo.rc" ]; then
  exec 3<>"$work/pipe"; exec 3>&-; wait
  bad "a symlink in the copy was opened: the check blocked on a FIFO behind it"
else
  wait; rc="$(cat "$work/fifo.rc")"; out="$(cat "$work/fifo.out")"
  [ "$rc" -eq 1 ] && ok "a symlink in the copy is never opened, and differs" || bad "fifo: exit $rc, wanted 1 -- $out"
  has "claude/rules/hatsu.md (symlink; never opened)" "the symlink is named as one"
fi
fresh linkout; ln -s /etc/hosts "$work/linkout/claude/rules/out.md"
expect 1 "a symlink pointing out of the copy is never read" --root "$src" --cache "$work/linkout"
fresh twinA; fresh twinB; ln -s ../README.md "$work/twinA/claude/rules/r.md"; ln -s ../README.md "$work/twinB/claude/rules/r.md"
expect 0 "two symlinks with the same target are equal" --root "$work/twinA" --cache "$work/twinB"

# a name carrying a control character is never compared or printed raw (Feitan, Phinks)
fresh cntrl; esc="$(printf '\033')"; printf 'x\n' > "$work/cntrl/claude/skills/${esc}[2J.md"
expect 1 "a control character in a copy's file name is different" --root "$src" --cache "$work/cntrl"
has "a name with a control character is never compared" "it is named as unexpected"
hasnt "$esc" "no control byte is printed"

# a copy is never its own evidence (Nobunaga's high)
ln -s "$src" "$work/linked"
expect 4 "a copy that is the source root itself, with nothing independent, is not comparable" --root "$src" --cache "$work/linked"
has "not comparable" "the verdict says so"
hasnt "identical" "never identical"
HATSU_PLUGIN_ROOT="$src" expect 0 "served by link to the git checkout HATSU_PLUGIN_ROOT names: identical" --root "$src" --cache "$work/linked"
has "served by link" "the link is said"
HATSU_PLUGIN_ROOT="$work/plain" expect 4 "a link to a source that is no git checkout is not comparable" --root "$work/plain" --cache "$work/plain"
HATSU_PLUGIN_ROOT="$src" expect 1 "the copy given as root is compared with the independent source" --root "$work/drift" --cache "$work/drift"
has "named by env" "the source's origin is said"
( cd "$src" && HATSU_PLUGIN_ROOT='' run --root "$work/drift" --cache "$work/drift"; [ "$rc" -eq 1 ] ) && ok "the Hatsu checkout the caller stands in is an independent source" || bad "cwd source -- $out"
# ...but only on its trunk, or on the branch the served copy is at (Nobunaga, pass 2): a feature
# worktree is the change being authored, never what should be served
git -C "$src" checkout -q -b feat/x
out="$(cd "$src" && HATSU_PLUGIN_ROOT='' perl -e 'alarm 20; exec @ARGV' bash "$check" --root "$work/drift" --cache "$work/drift" 2>&1)"; rc=$?
[ "$rc" -eq 4 ] && ok "a cwd on a feature branch is no independent source: not comparable" || bad "feature cwd: exit $rc, wanted 4 -- $out"
has "feat/x, a feature branch" "the skipped feature branch is named"
hasnt "different --" "a feature branch never reads as a stale served copy"
git clone -q "$src" "$work/servedgit" 2>/dev/null && git -C "$work/servedgit" checkout -q feat/x \
  && printf 'changed\n' > "$work/servedgit/claude/skills/ten/SKILL.md"
out="$(cd "$src" && HATSU_PLUGIN_ROOT='' perl -e 'alarm 20; exec @ARGV' bash "$check" --root "$work/servedgit" --cache "$work/servedgit" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && ok "a cwd on the branch the served checkout is at is an independent source" || bad "served-branch cwd: exit $rc, wanted 1 -- $out"
git -C "$src" checkout -q main

# --cache auto (Nobunaga's scenario: ten's root IS the recorded copy)
clear_cfg
expect 3 "auto with no record and no skills link: not installed" --root "$src" --cache auto
record "{\"version\":2,\"plugins\":{\"other@x\":[{\"installPath\":\"$work/drift\"}]}}"
expect 3 "auto ignores other plugins' entries" --root "$src" --cache auto
record "{\"version\":2,\"plugins\":{\"hatsu@hatsu\":[{\"installPath\":\"$work/same\"}]}}"
expect 0 "auto reads the hatsu@ installPath" --root "$src" --cache auto
expect 4 "auto: the recorded copy given as root, nothing independent: not comparable" --root "$work/same" --cache auto
record "{\"version\":2,\"plugins\":{\"hatsu@hatsu\":[{\"installPath\":\"$work/othername\"}]}}"
expect 5 "auto: a recorded hatsu@ copy naming another plugin is a broken install" --root "$src" --cache auto
has "holds no Hatsu plugin" "the broken install names the identity"
hasnt "refresh it" "no refresh instruction for a non-Hatsu record"
record "{\"version\":2,\"plugins\":{\"hatsu@hatsu\":[{\"installPath\":\"$work/same\"}]}}"
printf '{"mk":{"source":{"source":"directory","path":"%s"}}}\n' "$src" > "$cfg/plugins/known_marketplaces.json"
record "{\"version\":2,\"plugins\":{\"hatsu@mk\":[{\"installPath\":\"$work/drift\"}]}}"
expect 1 "auto: a stale copy given as root is compared with its directory marketplace" --root "$work/drift" --cache auto
has "named by marketplace" "the marketplace source is said"
rm "$cfg/plugins/known_marketplaces.json"
record "{\"version\":2,\"plugins\":{\"hatsu@hatsu\":[{\"installPath\":\"$work/drift\"},{\"installPath\":\"$work/same\"}]}}"
expect 1 "auto: one stale install of two is different, whatever its order" --root "$src" --cache auto
record "{\"version\":2,\"plugins\":{\"hatsu@hatsu\":[{\"installPath\":\"$work/same\"},{\"installPath\":\"$work/same\"}]}}"
expect 0 "auto: the same copy recorded twice is judged once" --root "$src" --cache auto
[ "$(printf '%s\n' "$out" | grep -c 'identical')" -eq 1 ] && ok "one verdict line for one copy" || bad "the same copy judged twice -- $out"
printf 'not json' > "$cfg/plugins/installed_plugins.json"
expect 5 "auto: an unreadable install record is a broken install, never wiring" --root "$src" --cache auto

# broken installs are said as broken, never as not installed (Phinks)
record '{"version":2,"plugins":{"hatsu@hatsu":[{"scope":"user","version":"1.2.0"}]}}'
expect 5 "auto: a hatsu@ entry with no installPath is broken" --root "$src" --cache auto
hasnt "not installed" "never not installed"
has "carries no usable installPath" "the empty entry is named as one"
record '{"version":2,"plugins":{"hatsu@hatsu":[]}}'
expect 5 "auto: a hatsu@ entry with no installs is broken" --root "$src" --cache auto
record '{"version":2,"plugins":{"hatsu@hatsu":[{"installPath":null}]}}'
expect 5 "auto: a null installPath is broken" --root "$src" --cache auto
record "{\"version\":2,\"plugins\":{\"hatsu@hatsu\":[{\"installPath\":\"$work/gone\"}]}}"
expect 5 "auto: a recorded path that is gone is a stale record" --root "$src" --cache auto
has "stale record" "the stale record is named"
printf '{"version":2,"plugins":{"hatsu@hatsu":[{"installPath":"%s\\n%s"}]}}\n' "$work/same" "$work/same" > "$cfg/plugins/installed_plugins.json"
expect 5 "auto: an installPath with a newline is one install, refused, never split" --root "$src" --cache auto
hasnt "identical" "never identical"
clear_cfg; mkdir -p "$cfg/skills"; ln -s "$work/moved" "$cfg/skills/hatsu"
expect 5 "auto: a dangling skills/hatsu link is broken" --root "$src" --cache auto
hasnt "not installed" "never not installed"
has "dangling or looping link" "the dangling link is named as one"
rm "$cfg/skills/hatsu"; ln -s "$cfg/skills/hatsu" "$cfg/skills/hatsu"
expect 5 "auto: a looping skills/hatsu link is broken" --root "$src" --cache auto
rm "$cfg/skills/hatsu"; ln -s "$src" "$cfg/skills/hatsu"
HATSU_PLUGIN_ROOT="$src" expect 0 "auto: the skills link to the named checkout is identical by link" --root "$src" --cache auto
rm "$cfg/skills/hatsu"; ln -s "$work/drift" "$cfg/skills/hatsu"
expect 1 "auto: a skills link to a stale checkout is different" --root "$src" --cache auto

# no jq: the record is unread, skills/hatsu judged, never a wiring stop (Chrollo, Nobunaga)
nojq="$work/nojq"; mkdir -p "$nojq"
for d in /usr/bin /bin /usr/sbin /sbin; do for t in "$d"/*; do
  n="$(basename "$t")"; [ "$n" = jq ] || [ -e "$nojq/$n" ] || ln -s "$t" "$nojq/$n" 2>/dev/null
done; done
record "{\"version\":2,\"plugins\":{\"hatsu@hatsu\":[{\"installPath\":\"$work/drift\"}]}}"
rm "$cfg/skills/hatsu"; ln -s "$work/same" "$cfg/skills/hatsu"
PATH="$nojq" expect 4 "no jq: the record is unread, the skills link still judged" --root "$src" --cache auto
has "unread" "the unread record is said"
PATH="$nojq" expect 0 "no jq: an explicit copy is still compared" --root "$src" --cache "$work/same"

# wiring
expect 2 "a root that is not a Hatsu checkout is wiring" --root "$work" --cache "$work/same"
mkdir -p "$work/hollow"
expect 2 "a cache with no plugin manifest is wiring" --root "$src" --cache "$work/hollow"
expect 2 "a cache that is not a directory is wiring" --root "$src" --cache "$work/nope"
expect 2 "an unknown argument is wiring" --root "$src" --cache "$work/same" --bogus
expect 2 "a missing --cache is wiring" --root "$src"
if [ "$(id -u)" != 0 ]; then
  fresh locked; chmod 000 "$work/locked/templates/pr-body.md"
  expect 2 "an unreadable cache file is wiring, never identical" --root "$src" --cache "$work/locked"
  chmod 644 "$work/locked/templates/pr-body.md"
  fresh lockeddir; chmod 000 "$work/lockeddir/claude/agents"
  expect 2 "an unreadable cache directory is wiring, never different" --root "$src" --cache "$work/lockeddir"
  has "could not be listed" "the unreadable directory is said"
  hasnt "only in source" "an unreadable directory never reads as missing files"
  chmod 755 "$work/lockeddir/claude/agents"
fi

echo "plugin-cache-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
