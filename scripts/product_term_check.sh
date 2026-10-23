#!/bin/sh
# product_term_check.sh — forwarding shim for the product-term guard hatsu:bankai-rule § 4 runs on a
# drafted pair row and on the pair file and INDEX before any write (zheref/hatsu#354, wave 3). The rule,
# the CLI and the exit codes are product_term_check.mts's header (BC-11 / HR-171: a three-way verdict is
# TypeScript's). A missing node, or one below the type-stripping floor, exits 2 here (never 1, the hit code).
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || exit 2
command -v node >/dev/null 2>&1 || { echo 'product_term_check: node not found' >&2; exit 2; }
v=$(node --version 2>/dev/null) || v=''
IFS=. read -r maj min _rest <<NODE_VERSION_EOF
${v#v}
NODE_VERSION_EOF
case "$maj.$min" in *[!0-9.]*|.*|*.) maj=0 min=0 ;; esac
if [ "$maj" -ge 24 ] || { [ "$maj" -eq 23 ] && [ "$min" -ge 6 ]; } || { [ "$maj" -eq 22 ] && [ "$min" -ge 18 ]; }; then
  exec node "$here/product_term_check.mts" "$@"
fi
echo "product_term_check: node >= 22.18 required (found ${v:-no version}; on 23.x, >= 23.6)" >&2
exit 2
