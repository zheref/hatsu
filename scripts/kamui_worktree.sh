#!/bin/sh
# kamui_worktree.sh — the clean worktree a build-and-send runs in, and the maintainer's own
# gitignored preconditions copied into it FROM THE CORE CHECKOUT. kamui § 3 (zheref/hatsu#146).
#
#   scripts/kamui_worktree.sh --repo <any checkout of the project> [--base <branch>] [--dry-run]
#   scripts/kamui_worktree.sh --self-test
#
# THE MAINTAINER'S RULINGS THIS EXECUTES (2026-09-29, HA-IS-#146, quoted):
#   "Great to collapse Step #1 and #2 if fully idempotent."
#   "Let's have the composite ALWAYS copy own file from core checkout."
#
# WHAT IT DOES, in order — every mutation refuses rather than guesses:
#   1. resolve CORE — the checkout whose .git is the common dir (the same derivation
#      `nen wc worktrees` reports as `core`); --repo may be core or any of its worktrees
#   2. `git fetch origin <base>` (skipped under --dry-run: the plan reads the last-fetched tip
#      and says so) — the tip is origin/<base>, never a local branch
#   3. ONE worktree at a FIXED path, <core>/.nen/worktrees/kamui, detached at that tip:
#        absent                       -> `git worktree add --detach`         (created)
#        present, clean, at the tip   -> nothing                              (reused)   <- idempotent
#        present, clean, elsewhere    -> `git checkout --detach <tip>` inside it (moved)
#        present, DIRTY               -> exit 2 listing every path; NEVER discarded
#        present, not a worktree      -> exit 2: a stray directory is somebody's, not ours
#        registered but gone (prunable) -> pruned, then created
#   4. copy each nen/contract.json -> project.fromCore[].path FROM CORE into the worktree.
#      A declared path must be: repo-relative and inside the tree; NOT tracked (a tracked file is
#      already in the worktree); gitignored (an unignored copy would dirty the worktree and refuse
#      the next run); present in core as a regular file, not a symlink. Anything else is exit 2 in
#      the declaration's own words. NOTHING IS SYNTHESISED and nothing comes from any other checkout.
#      No fromCore block: `copied: none declared`, not an error.
#
# exit 0  the worktree stands at the tip with every declared file copied; the lines below printed
# exit 2  refused, reason on stderr — nothing else was changed
#
# stdout, always:
#   core:            <path>
#   origin/<base>:   <sha>            (dry run: "as last fetched")
#   worktree:        <path> (created | reused | moved | would create | would move)
#   head:            <sha>
#   copied:          <path> (from core, gitignored)      one line per path, or "none declared"

usage() {
  echo "usage: kamui_worktree.sh --repo <path> [--base <branch>] [--dry-run]" >&2
  echo "       kamui_worktree.sh --self-test" >&2
}

# ---------------------------------------------------------------------------
# --self-test — hermetic, offline: a bare origin, a core clone, a declared fromCore path.
# ---------------------------------------------------------------------------
st_fails=0
st_out=""

st_run() {  # st_run <expected exit> <label> [args...]
  st_want="$1"; st_label="$2"; shift 2
  st_out="$(sh "$st_self" "$@" 2>&1)"; st_rc=$?
  if [ "$st_rc" -eq "$st_want" ]; then
    echo "  ok    $st_label (exit $st_rc)"
  else
    echo "  FAIL  $st_label: expected exit $st_want, got $st_rc" >&2
    echo "$st_out" | sed 's/^/          /' >&2
    st_fails=$((st_fails + 1))
  fi
}

st_says() {  # st_says <substring> <label>
  case "$st_out" in
    *"$1"*) echo "  ok    $2" ;;
    *) echo "  FAIL  $2: output does not carry '$1'" >&2
       echo "$st_out" | sed 's/^/          /' >&2
       st_fails=$((st_fails + 1)) ;;
  esac
}

st_git() { git -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }

st_contract() {  # st_contract <core> <fromCore json array or empty for none>
  if [ -n "$2" ]; then
    printf '{ "project": { "lanes": { "app": { "stack": "xcode-ios", "cwd": "." } }, "fromCore": %s } }\n' "$2" >"$1/nen/contract.json"
  else
    printf '{ "project": { "lanes": { "app": { "stack": "xcode-ios", "cwd": "." } } } }\n' >"$1/nen/contract.json"
  fi
}

st_build() {  # st_build <dir>
  git init -q --bare "$1/origin.git" >/dev/null 2>&1 || return 1
  git -C "$1/origin.git" symbolic-ref HEAD refs/heads/main
  git init -q "$1/core" >/dev/null 2>&1 || return 1
  git -C "$1/core" symbolic-ref HEAD refs/heads/main
  mkdir -p "$1/core/nen" "$1/core/Kro"
  printf '{ "branch": { "base": "main" } }\n' >"$1/core/nen/workflow.json"
  st_contract "$1/core" '[ { "path": "Kro/Config.xcconfig", "why": "gitignored credentials, core only" } ]'
  printf '/Kro/Config.xcconfig\n.nen/\n' >"$1/core/.gitignore"
  printf 'hello\n' >"$1/core/README"
  st_git -C "$1/core" add -A
  st_git -C "$1/core" commit -q -m base
  git -C "$1/core" remote add origin "$1/origin.git"
  git -C "$1/core" push -q origin main
  git -C "$1/core" fetch -q origin main
  printf 'SUPABASE_URL = x\n' >"$1/core/Kro/Config.xcconfig"   # the maintainer's own, gitignored
  st_sha="$(git -C "$1/core" rev-parse HEAD)"
}

self_test_main() {
  st_self="$(cd -P -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")"
  st_tmp="$(mktemp -d "${TMPDIR:-/tmp}/kamui-worktree-selftest.XXXXXX")" || return 2
  trap 'chmod -R u+rwX "$st_tmp" 2>/dev/null; rm -rf "$st_tmp"' EXIT INT TERM HUP
  # Canonical, because the script prints canonical paths (macOS puts $TMPDIR under /private, and a
  # TMPDIR with a trailing slash would otherwise leave a '//' in the expected string).
  st_tmp="$(cd -P -- "$st_tmp" && pwd -P)"
  GIT_AUTHOR_NAME=selftest GIT_AUTHOR_EMAIL=selftest@example.invalid
  GIT_COMMITTER_NAME=selftest GIT_COMMITTER_EMAIL=selftest@example.invalid
  export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
  st_build "$st_tmp" || { echo "kamui_worktree.sh --self-test: could not build the fixture" >&2; return 2; }
  core="$st_tmp/core"; wt="$core/.nen/worktrees/kamui"

  echo "kamui_worktree.sh --self-test"

  # --- the argument parser ----------------------------------------------------------------------
  st_run 2 "--repo with no value is refused" --repo
  st_run 2 "--base with no value is refused" --repo "$core" --base
  st_run 2 "no --repo is refused" --dry-run
  st_run 2 "an unknown argument is refused" --repo "$core" --nope
  st_run 2 "a path that is not a git repository is refused" --repo "$st_tmp"

  # --- the plan, then the creation ----------------------------------------------------------------
  st_run 0 "--dry-run on a fresh core prints the plan and creates nothing" --repo "$core" --dry-run
  st_says "would create" "and says would create"
  [ ! -e "$wt" ] && echo "  ok    and the worktree does not exist after the dry run" \
    || { echo "  FAIL  the dry run created the worktree" >&2; st_fails=$((st_fails + 1)); }

  st_run 0 "a fresh core gets one worktree at origin/main's tip with the declared file copied" --repo "$core"
  st_says "worktree:        $wt (created)" "and says created"
  st_says "copied:          Kro/Config.xcconfig (from core, gitignored)" "and names the copied path"
  [ -f "$wt/Kro/Config.xcconfig" ] && echo "  ok    and the file is in the worktree" \
    || { echo "  FAIL  the file was not copied" >&2; st_fails=$((st_fails + 1)); }
  [ "$(git -C "$wt" rev-parse HEAD)" = "$st_sha" ] && echo "  ok    and the worktree's HEAD is the tip" \
    || { echo "  FAIL  the worktree is not at the tip" >&2; st_fails=$((st_fails + 1)); }
  [ -z "$(git -C "$wt" status --porcelain)" ] && echo "  ok    and the worktree is clean after the copy (the path is ignored)" \
    || { echo "  FAIL  the copy dirtied the worktree" >&2; st_fails=$((st_fails + 1)); }

  # --- idempotence: a second run at the same tip is a no-op, not a second worktree ---------------
  st_run 0 "a second run at the same tip reuses the worktree" --repo "$core"
  st_says "(reused)" "and says reused"
  n="$(git -C "$core" worktree list --porcelain | grep -c '^worktree ')"
  [ "$n" -eq 2 ] && echo "  ok    and there is still exactly one kamui worktree beside core" \
    || { echo "  FAIL  expected 2 worktrees, found $n" >&2; st_fails=$((st_fails + 1)); }

  # --- invoked FROM the worktree, core still resolves ---------------------------------------------
  st_run 0 "invoked from the worktree, core is resolved and the run is a no-op" --repo "$wt"
  st_says "core:            $core" "and names core"

  # --- the trunk moves on: a clean worktree is moved to the new tip -------------------------------
  git clone -q "$st_tmp/origin.git" "$st_tmp/other" 2>/dev/null
  printf 'newer\n' >>"$st_tmp/other/README"; st_git -C "$st_tmp/other" commit -q -am newer
  git -C "$st_tmp/other" push -q origin main
  st_new="$(git -C "$st_tmp/other" rev-parse HEAD)"
  st_run 0 "when origin/main moves, a clean worktree is moved to the new tip" --repo "$core"
  st_says "(moved)" "and says moved"
  st_says "head:            $st_new" "and names the new head"

  # --- a dirty worktree is refused, never discarded -----------------------------------------------
  printf 'edit\n' >>"$wt/README"
  st_run 2 "a dirty kamui worktree is refused with its paths, never discarded" --repo "$core"
  st_says "README" "and lists the dirty path"
  git -C "$wt" checkout -q -- README

  # --- the declaration ---------------------------------------------------------------------------
  cp "$core/nen/contract.json" "$st_tmp/contract.bak"
  st_contract "$core" '[ { "path": "README", "why": "tracked" } ]'
  st_run 2 "a fromCore path that is tracked is refused" --repo "$core"
  st_says "tracked" "and says tracked"

  st_contract "$core" '[ { "path": "Kro/Secret.env", "why": "not ignored" } ]'
  printf 'x\n' >"$core/Kro/Secret.env"
  st_run 2 "a fromCore path that is not gitignored is refused" --repo "$core"
  st_says "gitignored" "and says why"
  rm -f "$core/Kro/Secret.env"

  st_contract "$core" '[ { "path": "Kro/Missing.xcconfig", "why": "absent in core" } ]'
  printf '/Kro/Missing.xcconfig\n' >>"$core/.gitignore"
  st_run 2 "a fromCore path absent in core is refused: nothing is synthesised" --repo "$core"
  st_says "absent in core" "and says absent"

  st_contract "$core" '[ { "path": "../outside", "why": "escapes" } ]'
  st_run 2 "a fromCore path that leaves the tree is refused" --repo "$core"

  st_contract "$core" '[ { "path": "Kro/Link.xcconfig", "why": "symlink" } ]'
  printf '/Kro/Link.xcconfig\n' >>"$core/.gitignore"
  ln -s /etc/hosts "$core/Kro/Link.xcconfig"
  st_run 2 "a symlinked fromCore source is refused" --repo "$core"
  rm -f "$core/Kro/Link.xcconfig"

  st_contract "$core" ""
  git -C "$core" checkout -q -- .gitignore
  st_run 0 "no fromCore block copies nothing and says so" --repo "$core"
  st_says "copied:          none declared" "and says none declared"
  cp "$st_tmp/contract.bak" "$core/nen/contract.json"

  # --- a stray directory at the fixed path is somebody's -----------------------------------------
  git -C "$core" worktree remove --force "$wt"
  mkdir -p "$wt"; : >"$wt/stray"
  st_run 2 "a directory at the fixed path that is not a worktree is refused" --repo "$core"
  st_says "not a worktree" "and says so"
  rm -rf "$wt"

  # --- a registered worktree whose directory is gone is pruned, then created --------------------
  st_run 0 "after the stray is removed, the worktree is created again" --repo "$core"
  rm -rf "$wt"
  st_run 0 "a registered worktree whose directory vanished is pruned and re-created" --repo "$core"
  st_says "(created)" "and says created"

  if [ "$st_fails" -eq 0 ]; then
    echo "kamui_worktree.sh --self-test: all assertions held; nothing left this machine."
    return 0
  fi
  echo "kamui_worktree.sh --self-test: $st_fails assertion(s) failed" >&2
  return 1
}

repo=""; base=""; dry=0; self_test=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || { usage; exit 2; }; repo="$2"; shift 2 ;;
    --base) [ $# -ge 2 ] || { usage; exit 2; }; base="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    --self-test) self_test=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "kamui_worktree.sh: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done

if [ "$self_test" -eq 1 ]; then
  [ -z "$repo" ] && [ -z "$base" ] && [ "$dry" -eq 0 ] || { echo "kamui_worktree.sh: --self-test takes no other argument" >&2; exit 2; }
  self_test_main
  exit $?
fi

[ -n "$repo" ] || { usage; exit 2; }

# 1. CORE. The common dir is <core>/.git; any worktree of the project answers the same one.
common="$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
  || { echo "kamui_worktree.sh: not a git repository: $repo" >&2; exit 2; }
core="$(cd -P -- "$(dirname -- "$common")" && pwd -P)" || { echo "kamui_worktree.sh: core does not resolve from $common" >&2; exit 2; }
[ -d "$core/.git" ] || [ -f "$core/.git" ] || { echo "kamui_worktree.sh: $core is not a checkout -- refused" >&2; exit 2; }
wf="$core/nen/workflow.json"
contract="$core/nen/contract.json"
[ -f "$wf" ] || { echo "kamui_worktree.sh: no $wf -- refused" >&2; exit 2; }

if [ -z "$base" ]; then
  base="$(python3 -c 'import json,sys
b=json.load(open(sys.argv[1])).get("branch",{})
if not isinstance(b, dict): sys.exit("branch is not an object")
t=b.get("base","main")
if not isinstance(t, str) or not t: sys.exit("branch.base is not a non-empty string")
print(t)' "$wf")" || { echo "kamui_worktree.sh: branch.base unreadable -- refused" >&2; exit 2; }
fi
git -C "$core" check-ref-format --allow-onelevel "$base" \
  || { echo "kamui_worktree.sh: base is not a legal git ref name -- refused" >&2; exit 2; }

# THE DECLARED COPY LIST, read as data before anything moves, so a bad declaration costs nothing.
copies=""
if [ -f "$contract" ]; then
  copies="$(python3 -c 'import json,sys
p=json.load(open(sys.argv[1])).get("project")
if not isinstance(p, dict): sys.exit(3)
f=p.get("fromCore")
if f is None: sys.exit(3)
if not isinstance(f, list): sys.exit("project.fromCore is not a list")
for i,e in enumerate(f):
    if not isinstance(e, dict) or not isinstance(e.get("path"), str) or not e["path"]:
        sys.exit("project.fromCore[%d] has no path string" % i)
    if "\n" in e["path"]: sys.exit("project.fromCore[%d].path carries a newline" % i)
    print(e["path"])' "$contract")"; rc=$?
  case $rc in
    0|3) [ $rc -eq 3 ] && copies="" ;;
    *) echo "kamui_worktree.sh: $contract could not be read for project.fromCore -- refused" >&2; exit 2 ;;
  esac
fi
# Every declared path is proven in CORE now: relative, inside the tree, untracked, ignored, a file.
for p in $copies; do
  case "$p" in
    /*|../*|*/../*|*/..|..) echo "kamui_worktree.sh: fromCore path '$p' is not repo-relative inside the tree -- refused" >&2; exit 2 ;;
  esac
  if git -C "$core" ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
    echo "kamui_worktree.sh: fromCore path '$p' is tracked -- a tracked file is already in every worktree; refused" >&2; exit 2
  fi
  git -C "$core" check-ignore -q -- "$p" \
    || { echo "kamui_worktree.sh: fromCore path '$p' is not gitignored -- a copy would dirty the worktree and refuse the next run; refused" >&2; exit 2; }
  [ -L "$core/$p" ] && { echo "kamui_worktree.sh: fromCore path '$p' is a symlink in core -- refused" >&2; exit 2; }
  [ -f "$core/$p" ] || { echo "kamui_worktree.sh: fromCore path '$p' is absent in core -- the maintainer's own checkout is where it comes from and nothing is synthesised; refused" >&2; exit 2; }
done

# 2. THE TIP. Fetched for real, or read as last fetched under --dry-run.
if [ "$dry" -eq 0 ]; then
  git -C "$core" fetch -q origin "refs/heads/$base:refs/remotes/origin/$base" 2>/dev/null \
    || { echo "kamui_worktree.sh: git fetch origin $base failed -- refused, the tip is unknown" >&2; exit 2; }
fi
tip="$(git -C "$core" rev-parse --verify -q "refs/remotes/origin/$base")" \
  || { echo "kamui_worktree.sh: origin/$base does not resolve -- refused" >&2; exit 2; }

# 3. ONE WORKTREE AT ONE PATH.
wt="$core/.nen/worktrees/kamui"
state=""
registered=0
case "$(git -C "$core" worktree list --porcelain)" in
  *"worktree $wt"*) registered=1 ;;
esac
if [ "$registered" -eq 1 ] && [ ! -d "$wt" ]; then
  [ "$dry" -eq 1 ] || git -C "$core" worktree prune
  registered=0
fi
if [ -e "$wt" ] && [ "$registered" -eq 0 ]; then
  echo "kamui_worktree.sh: $wt exists and is not a worktree of this project -- somebody's directory, refused" >&2; exit 2
fi
if [ "$registered" -eq 1 ]; then
  if [ -n "$(git -C "$wt" status --porcelain)" ]; then
    echo "kamui_worktree.sh: the kamui worktree at $wt is dirty -- refused, never discarded:" >&2
    git -C "$wt" status --porcelain | sed 's/^/    /' >&2
    exit 2
  fi
  if [ "$(git -C "$wt" rev-parse HEAD)" = "$tip" ]; then
    state="reused"
  elif [ "$dry" -eq 1 ]; then
    state="would move"
  else
    git -C "$wt" checkout -q --detach "$tip" || { echo "kamui_worktree.sh: could not move $wt to $tip -- refused" >&2; exit 2; }
    state="moved"
  fi
elif [ "$dry" -eq 1 ]; then
  state="would create"
else
  mkdir -p "$(dirname -- "$wt")"
  git -C "$core" worktree add -q --detach "$wt" "$tip" || { echo "kamui_worktree.sh: git worktree add failed -- refused" >&2; exit 2; }
  state="created"
fi

printf 'core:            %s\n' "$core"
if [ "$dry" -eq 1 ]; then printf 'origin/%s:   %s (as last fetched; --dry-run fetches nothing)\n' "$base" "$tip"
else printf 'origin/%s:   %s\n' "$base" "$tip"; fi
printf 'worktree:        %s (%s)\n' "$wt" "$state"
printf 'head:            %s\n' "$tip"

# 4. THE COPY, always from core, never synthesised.
if [ -z "$copies" ]; then
  printf 'copied:          none declared (nen/contract.json -> project.fromCore)\n'
else
  for p in $copies; do
    if [ "$dry" -eq 1 ]; then
      printf 'copied:          %s (would copy from core)\n' "$p"
    else
      mkdir -p "$(dirname -- "$wt/$p")"
      cp -p -- "$core/$p" "$wt/$p" || { echo "kamui_worktree.sh: copying '$p' from core failed -- refused" >&2; exit 2; }
      printf 'copied:          %s (from core, gitignored)\n' "$p"
    fi
  done
fi
exit 0
