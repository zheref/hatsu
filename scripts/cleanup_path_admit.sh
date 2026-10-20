#!/bin/sh
# cleanup_path_admit.sh — forwarding shim for hatsu:cleanup § 4's worktree-path admission
# (zheref/hatsu#333). The rule, the CLI and the exit codes are cleanup_path_admit.ts's header.
# A missing node, or one below the type-stripping floor, exits 2 here (never 1, the refusal code).
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || exit 2
command -v node >/dev/null 2>&1 || { echo 'cleanup_path_admit: node not found' >&2; exit 2; }
v=$(node --version 2>/dev/null) || v=''
IFS=. read -r maj min _rest <<NODE_VERSION_EOF
${v#v}
NODE_VERSION_EOF
case "$maj.$min" in *[!0-9.]*|.*|*.) maj=0 min=0 ;; esac
if [ "$maj" -ge 24 ] || { [ "$maj" -eq 23 ] && [ "$min" -ge 6 ]; } || { [ "$maj" -eq 22 ] && [ "$min" -ge 18 ]; }; then
  exec node "$here/cleanup_path_admit.ts" "$@"
fi
echo "cleanup_path_admit: node >= 22.18 required (found ${v:-no version}; on 23.x, >= 23.6)" >&2
exit 2
