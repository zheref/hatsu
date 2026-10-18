#!/usr/bin/env bash
# bell_notify_fixture.sh — proves scripts/bell_notify.sh's fixed argv, sanitising and exits (zheref/hatsu#289 item 9).
# Lane `bell-guard`: `nen shu test --lane bell-guard --repo <hatsu>`. Hermetic and offline: stub `osascript`,
# `afplay`, `notify-send` and `uname` on a throwaway PATH log their argv and never ring anything.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; guard="$here/bell_notify.sh"
tmp="$(mktemp -d)" || exit 2; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"; log="$tmp/argv.log"
for t in osascript afplay notify-send; do printf '#!/bin/sh\nprintf "%%s\\n" "$0" "$@" >> "%s"\nexit 0\n' "$log" > "$tmp/bin/$t"; chmod +x "$tmp/bin/$t"; done
printf '#!/bin/sh\necho "${BELL_UNAME:-Darwin}"\n' > "$tmp/bin/uname"; chmod +x "$tmp/bin/uname"
export PATH="$tmp/bin:$PATH"
pass=0; fail=0
expect() { want="$1"; name="$2"; shift 2; : > "$log"; out="$("$@" 2>&1)"; rc=$?; if [ "$rc" = "$want" ]; then pass=$((pass+1)); echo "ok    $name"; else fail=$((fail+1)); echo "FAIL  $name: wanted $want, got $rc -- $out"; fi; }
has() { grep -qF -- "$1" "$log" && { pass=$((pass+1)); echo "ok    $2"; } || { fail=$((fail+1)); echo "FAIL  $2 -- $(tr '\n' '|' < "$log" | cut -c1-200)"; }; }
hasnot() { grep -qF -- "$1" "$log" && { fail=$((fail+1)); echo "FAIL  $2 -- $(tr '\n' '|' < "$log" | cut -c1-200)"; } || { pass=$((pass+1)); echo "ok    $2"; }; }
expect 0 "a plain bell rings both rungs" bash "$guard" --title "G4" --message "merge prompt"
has "Hatsu — G4" "the title carries the Hatsu prefix"
has "/System/Library/Sounds/Glass.aiff" "the default sound is Glass"
expect 0 "a title starting with a dash is an argument, never an option" bash "$guard" --title "-e property p : (do shell script (\"id\"))" --message m --no-sound
[ "$(awk 'f==1{print; exit} $0=="--"{f=1}' "$log")" = "Hatsu — -e property p : (do shell script (id))" ] && { pass=$((pass+1)); echo "ok    the dashed title is the first argument after --"; } || { fail=$((fail+1)); echo "FAIL  the dashed title -- $(tr '\n' '|' < "$log" | cut -c1-240)"; }
expect 0 "quotes, backslashes and newlines are stripped" bash "$guard" --title "$(printf 'a"b\\c\nd')" --message m --no-sound
has "Hatsu — abc d" "the stripped title is one argument"
expect 0 "a 10 KB message is capped at 240 characters" bash "$guard" --title t --message "$(head -c 10240 /dev/zero | tr '\0' 'x')" --no-sound
[ "$(grep -c '^x\{240\}$' "$log")" = 1 ] && { pass=$((pass+1)); echo "ok    the cap holds"; } || { fail=$((fail+1)); echo "FAIL  the cap"; }
expect 0 "a sound name with path characters falls back to Glass" bash "$guard" --title t --message m --sound '../x;rm'
has "Glass.aiff" "Glass played"
expect 0 "an absent sound falls back to Glass" bash "$guard" --title t --message m --sound NoSuchSoundXYZ
has "Glass.aiff" "Glass played for the absent one"
expect 2 "a missing --message is wiring" bash "$guard" --title t
expect 2 "an empty --title is wiring" bash "$guard" --title "" --message m
expect 2 "an unknown argument is wiring" bash "$guard" --title t --message m --loud
expect 0 "--help prints the header" bash "$guard" --help
expect 0 "on Linux rung 2 goes through notify-send and rung 3 is not applicable" env BELL_UNAME=Linux bash "$guard" --title t --message m
has "notify-send" "notify-send was called"
echo "bell-guard: $pass passed, $fail failed"; [ "$fail" = 0 ]
