#!/bin/sh
# cleanup_path_admit.sh — forwarding shim for hatsu:cleanup § 4's worktree-path admission
# (zheref/hatsu#333). The rule, the CLI and the exit codes are cleanup_path_admit.ts's header.
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || exit 2
exec node "$here/cleanup_path_admit.ts" "$@"
