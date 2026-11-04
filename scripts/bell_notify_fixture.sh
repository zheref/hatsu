#!/usr/bin/env bash
# bell_notify_fixture.sh — proves scripts/bell_notify.sh's fixed argv, sanitising, deadline and exits
# (zheref/hatsu#289 item 9, zheref/hatsu#516). Lane `bell-guard`: `nen shu test --lane bell-guard --repo <hatsu>`.
# Hermetic and offline: stub `osascript`, `afplay`, `notify-send` and `uname` on a throwaway PATH log their argv
# and never ring anything. STUB_OSASCRIPT / STUB_AFPLAY pick a stub's behaviour: ok (default), fail (stderr,
# exit 1), hang (never returns) or stubborn (never returns and ignores TERM). The afplay stub refuses a `--`
# as the player did in #516. Every hung stub records its PID; the trap below stops only those PIDs.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; guard="$here/bell_notify.sh"
tmp="$(mktemp -d)" || exit 2
decoy=""
cleanup() {
  for p in "$tmp"/*.pid; do [ -f "$p" ] && kill -KILL "$(cat "$p")" 2>/dev/null; done
  [ -n "$decoy" ] && kill -KILL "$decoy" 2>/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/bin" "$tmp/core" "$tmp/no-afplay" "$tmp/no-osascript" "$tmp/decoy"; log="$tmp/argv.log"
cat > "$tmp/stub" <<EOF
#!/bin/sh
n="\$(basename "\$0")"; d="$tmp"
printf '%s\n' "\$0" "\$@" >> "\$d/argv.log"; printf '%s\n' "\$@" > "\$d/\$n.argv"; echo x >> "\$d/\$n.calls"
case "\$n" in osascript) mode="\${STUB_OSASCRIPT:-ok}" ;; afplay) mode="\${STUB_AFPLAY:-ok}" ;; *) mode=ok ;; esac
if [ "\$n" = afplay ] && [ "\${1-}" = "--" ]; then echo "afplay: unsupported option --" >&2; exit 1; fi
case "\$mode" in
  fail) echo "\$n: stub execution error" >&2; exit 1 ;;
  hang) echo \$\$ > "\$d/\$n.pid"; exec sleep 30 ;;
  stubborn) trap '' TERM; echo \$\$ > "\$d/\$n.pid"; exec sleep 30 ;;
esac
exit 0
EOF
chmod +x "$tmp/stub"
for t in osascript afplay notify-send; do cp "$tmp/stub" "$tmp/bin/$t"; done
printf '#!/bin/sh\necho "${BELL_UNAME:-Darwin}"\n' > "$tmp/bin/uname"; chmod +x "$tmp/bin/uname"
# A PATH holding only what bell_notify.sh itself needs, so a missing tool is really missing.
for t in tr cut mktemp sleep rm awk basename cat; do ln -s "$(command -v "$t")" "$tmp/core/$t"; done
for t in osascript uname; do cp "$tmp/bin/$t" "$tmp/no-afplay/$t"; done
for t in afplay uname; do cp "$tmp/bin/$t" "$tmp/no-osascript/$t"; done
printf '#!/bin/sh\nexec sleep 30\n' > "$tmp/decoy/osascript"; chmod +x "$tmp/decoy/osascript"
export PATH="$tmp/bin:$PATH"
pass=0; fail=0; out=""
ok() { pass=$((pass+1)); echo "ok    $1"; }
no() { fail=$((fail+1)); echo "FAIL  $1"; }
reset() { : > "$log"; rm -f "$tmp"/*.argv "$tmp"/*.calls "$tmp"/*.pid; }
expect() { want="$1"; name="$2"; shift 2; reset; out="$("$@" 2>&1)"; rc=$?; if [ "$rc" = "$want" ]; then ok "$name"; else no "$name: wanted $want, got $rc -- $out"; fi; }
has() { grep -qF -- "$1" "$log" && ok "$2" || no "$2 -- $(tr '\n' '|' < "$log" | cut -c1-200)"; }
says() { printf '%s\n' "$out" | grep -qF -- "$1" && ok "$2" || no "$2 -- $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)"; }
saysnot() { printf '%s\n' "$out" | grep -qF -- "$1" && no "$2 -- $(printf '%s' "$out" | tr '\n' '|' | cut -c1-240)" || ok "$2"; }
calls() { c=0; [ -f "$tmp/$1.calls" ] && c="$(wc -l < "$tmp/$1.calls" | tr -d ' ')"; [ "$c" = "$2" ] && ok "$3" || no "$3: $1 called $c times, wanted $2"; }
gone() { p="$(cat "$tmp/$1.pid" 2>/dev/null)"; if [ -z "$p" ]; then no "$2: no PID recorded"; elif kill -0 "$p" 2>/dev/null; then no "$2: PID $p still running"; else ok "$2"; fi; }
within() { [ "$1" -le "$2" ] && ok "$3 (${1}s)" || no "$3: took ${1}s, bound ${2}s"; }

expect 0 "a plain bell rings both rungs" bash "$guard" --title "G4" --message "merge prompt"
has "Hatsu — G4" "the title carries the Hatsu prefix"
has "/System/Library/Sounds/Glass.aiff" "the default sound is Glass"
[ "$(cat "$tmp/afplay.argv" 2>/dev/null)" = "/System/Library/Sounds/Glass.aiff" ] && ok "afplay gets the absolute path alone, no --" || no "afplay argv -- $(tr '\n' '|' < "$tmp/afplay.argv" 2>/dev/null)"
calls afplay 1 "the sound is attempted once"
says "rung 2 (OS notification): sent" "a clean notification run reads sent"
says "rung 3 (sound): played Glass" "a clean player run reads played"
expect 0 "a title starting with a dash is an argument, never an option" bash "$guard" --title "-e property p : (do shell script (\"id\"))" --message m --no-sound
[ "$(awk 'f==1{print; exit} $0=="--"{f=1}' "$log")" = "Hatsu — -e property p : (do shell script (id))" ] && ok "the dashed title is the first argument after --" || no "the dashed title -- $(tr '\n' '|' < "$log" | cut -c1-240)"
calls afplay 0 "--no-sound plays nothing"
expect 0 "quotes, backslashes and newlines are stripped" bash "$guard" --title "$(printf 'a"b\\c\nd')" --message m --no-sound
has "Hatsu — abc d" "the stripped title is one argument"
expect 0 "a 10 KB message is capped at 240 characters" bash "$guard" --title t --message "$(head -c 10240 /dev/zero | tr '\0' 'x')" --no-sound
[ "$(grep -c '^x\{240\}$' "$log")" = 1 ] && ok "the cap holds" || no "the cap"
expect 0 "a sound name with path characters falls back to Glass" bash "$guard" --title t --message m --sound '../x;rm'
has "Glass.aiff" "Glass played"
expect 0 "an absent sound falls back to Glass" bash "$guard" --title t --message m --sound NoSuchSoundXYZ
has "Glass.aiff" "Glass played for the absent one"

# Unavailable capability is not a failure, and neither is ever a success (#516 AC-2).
expect 0 "no player on PATH is reported, not run" env PATH="$tmp/no-afplay:$tmp/core" "$BASH" "$guard" --title t --message m
says "rung 3 (sound): not applicable, no afplay" "a missing player reads not applicable"
saysnot "played" "a missing player never reads played"
expect 0 "no osascript on PATH is reported, and the sound still runs" env PATH="$tmp/no-osascript:$tmp/core" "$BASH" "$guard" --title t --message m
says "rung 2 (OS notification): not applicable, no osascript" "a missing notifier reads not applicable"
says "rung 3 (sound): played Glass" "the sound runs without the notifier"
expect 0 "a failing player is a failure, not a missing seat" env STUB_AFPLAY=fail bash "$guard" --title t --message m
says "rung 3 (sound): failed (exit 1: afplay: stub execution error)" "the player's exit and stderr are quoted"
saysnot "played" "a failing player never reads played"
saysnot "not applicable" "a failing player never reads not applicable"
calls afplay 1 "a failing player is not retried"
expect 0 "a failing notifier is a failure, and the sound still runs once" env STUB_OSASCRIPT=fail bash "$guard" --title t --message m
says "rung 2 (OS notification): failed (exit 1: osascript: stub execution error)" "the notifier's exit and stderr are quoted"
saysnot "sent" "a failing notifier never reads sent"
calls afplay 1 "the sound follows a failed notification once"

# A notification that never returns is bounded, its own child stopped, the sound still tried (#516 AC-4/5).
"$tmp/decoy/osascript" & decoy=$!  # a hung process of the same name and shape this run did not start
reset; start=$SECONDS; out="$(env STUB_OSASCRIPT=hang bash "$guard" --title t --message m --deadline 1 2>&1)"; rc=$?; took=$((SECONDS - start))
[ "$rc" = 0 ] && ok "a hung notifier still exits 0" || no "a hung notifier exit: $rc -- $out"
within "$took" 4 "a hung notifier returns within the bound"
says "rung 2 (OS notification): timed out after 1s, its own child stopped" "the timeout is reported"
saysnot "sent" "a timed-out notifier never reads sent"
gone osascript "the hung child was stopped and reaped"
kill -0 "$decoy" 2>/dev/null && ok "a same-named process this run did not start is untouched" || no "the decoy was killed"
kill -KILL "$decoy" 2>/dev/null; wait "$decoy" 2>/dev/null; decoy=""
says "rung 3 (sound): played Glass" "the sound runs after the timeout"
calls afplay 1 "the sound follows the timeout once"
reset; start=$SECONDS; out="$(env STUB_OSASCRIPT=stubborn bash "$guard" --title t --message m --deadline 1 --no-sound 2>&1)"; took=$((SECONDS - start))
within "$took" 4 "a child ignoring TERM is KILLed within the bound"
gone osascript "the TERM-ignoring child was stopped and reaped"
reset; start=$SECONDS; out="$(env STUB_AFPLAY=hang bash "$guard" --title t --message m --deadline 1 2>&1)"; took=$((SECONDS - start))
within "$took" 4 "a hung player returns within the bound"
says "rung 3 (sound): timed out after 1s, its own child stopped" "the player timeout is reported"
saysnot "played" "a timed-out player never reads played"
gone afplay "the hung player was stopped and reaped"

expect 2 "a missing --message is wiring" bash "$guard" --title t
expect 2 "an empty --title is wiring" bash "$guard" --title "" --message m
expect 2 "an unknown argument is wiring" bash "$guard" --title t --message m --loud
expect 2 "a zero deadline is wiring" bash "$guard" --title t --message m --deadline 0
expect 2 "a deadline past 60 seconds is wiring" bash "$guard" --title t --message m --deadline 61
expect 2 "a non-numeric deadline is wiring" bash "$guard" --title t --message m --deadline 5s
expect 0 "a leading-zero deadline is decimal" bash "$guard" --title t --message m --deadline 08 --no-sound
expect 0 "--help prints the header" bash "$guard" --help
says "--deadline" "the header documents the deadline"
expect 0 "on Linux rung 2 goes through notify-send and rung 3 is not applicable" env BELL_UNAME=Linux bash "$guard" --title t --message m
has "notify-send" "notify-send was called"
echo "bell-guard: $pass passed, $fail failed"; [ "$fail" = 0 ]
