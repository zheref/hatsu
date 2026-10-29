#!/bin/sh
# Dedicated POSIX fixture for report_time.sh (HA148). The original self-test assertions live here
# so exact-source production coverage does not count fixture code as runtime implementation.
script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)" || exit 2
report_time="$script_dir/report_time.sh"

self_test() {
  st_fails=0
  st_self="$report_time"
  coverage_exec="${HATSU_SHELL_COVERAGE_EXEC:-}"
  if [ -n "$coverage_exec" ]; then
    # Only the declared target traces; fixture assertions and child shells stay plain.
    set +x
    export HATSU_SHELL_COVERAGE_PS4="${PS4-}" HATSU_SHELL_COVERAGE_TRACE_FD="${BASH_XTRACEFD-}"
    export -n PS4 BASH_XTRACEFD SHELLOPTS
    [ "${HATSU_SHELL_COVERAGE_TARGET:-}" = "scripts/report_time.sh" ] && [ -x "$coverage_exec" ] || exit 2
  fi
  st_self="${coverage_exec:-$st_self}"
  st_expect() {  # st_expect <label> <expected output> [args...]
    st_label="$1"; st_want="$2"; shift 2
    st_got="$("$st_self" "$@" 2>&1)"; st_rc=$?
    if [ "$st_rc" -eq 0 ] && [ "$st_got" = "$st_want" ]; then
      echo "ok    $st_label"
    else
      echo "FAIL  $st_label (exit $st_rc)"; echo "      want: $st_want"; echo "      got:  $st_got"
      st_fails=$((st_fails + 1))
    fi
  }
  st_refuse() {  # st_refuse <label> [args...]
    st_label="$1"; shift
    st_got="$("$st_self" "$@" 2>&1)"; st_rc=$?
    if [ "$st_rc" -eq 2 ]; then echo "ok    $st_label (refused)"; else
      echo "FAIL  $st_label: want exit 2, got $st_rc: $st_got"; st_fails=$((st_fails + 1)); fi
  }
  nl='
'
  st_expect "afternoon in Bogota" \
    "generatedAtLocal=Tue 22 Sep 2026 · 14:05 America/Bogota (UTC-05:00)${nl}generatedDateLocal=2026-09-22${nl}timeZone=America/Bogota" \
    --at 2026-09-22T19:05:00Z --tz America/Bogota
  st_expect "UTC past midnight is still yesterday locally; fractions and +00:00 read" \
    "generatedAtLocal=Tue 22 Sep 2026 · 21:30 America/Bogota (UTC-05:00)${nl}generatedDateLocal=2026-09-22${nl}timeZone=America/Bogota" \
    --at 2026-09-23T02:30:00.267+00:00 --tz America/Bogota
  st_expect "ahead of UTC flips to tomorrow; single-digit day unpadded" \
    "generatedAtLocal=Fri 2 Oct 2026 · 04:05 Asia/Tokyo (UTC+09:00)${nl}generatedDateLocal=2026-10-02${nl}timeZone=Asia/Tokyo" \
    --at 2026-10-01T19:05Z --tz Asia/Tokyo
  st_expect "half-hour offset" \
    "generatedAtLocal=Wed 23 Sep 2026 · 00:35 Asia/Kolkata (UTC+05:30)${nl}generatedDateLocal=2026-09-23${nl}timeZone=Asia/Kolkata" \
    --at 2026-09-22T19:05:00Z --tz Asia/Kolkata
  st_host="$(mktemp -d)"
  mkdir -p "$st_host/zoneinfo/America"
  ln -s ../zoneinfo/America/Bogota "$st_host/relative-link"
  printf 'TZif-copy' > "$st_host/copied"
  printf '  America/Bogota  \n' > "$st_host/timezone"
  st_zone() { env -u TZ REPORT_TIME_LOCALTIME="$1" REPORT_TIME_TIMEZONE_FILE="$2" "$st_self" --at 2026-09-22T19:05:00Z 2>&1; }
  st_got="$(st_zone "$st_host/relative-link" "$st_host/none" | sed -n 3p)"
  if [ "$st_got" = "timeZone=America/Bogota" ]; then echo "ok    a relative localtime symlink names the zone"; else
    echo "FAIL  a relative localtime symlink names the zone: got $st_got"; st_fails=$((st_fails + 1)); fi
  st_got="$(st_zone "$st_host/copied" "$st_host/timezone" | sed -n 3p)"
  if [ "$st_got" = "timeZone=America/Bogota" ]; then echo "ok    a copied localtime is named by /etc/timezone"; else
    echo "FAIL  a copied localtime is named by /etc/timezone: got $st_got"; st_fails=$((st_fails + 1)); fi
  st_zone "$st_host/copied" "$st_host/none" >/dev/null; st_rc=$?
  if [ "$st_rc" -eq 2 ]; then echo "ok    a copied localtime nothing names is refused, never guessed as UTC (refused)"; else
    echo "FAIL  a copied localtime nothing names: want exit 2, got $st_rc"; st_fails=$((st_fails + 1)); fi
  st_got="$(st_zone "$st_host/absent" "$st_host/none" | sed -n 3p)"
  if [ "$st_got" = "timeZone=UTC" ]; then echo "ok    no localtime at all is UTC, as libc answers"; else
    echo "FAIL  no localtime at all is UTC: got $st_got"; st_fails=$((st_fails + 1)); fi
  rm -rf "$st_host"
  st_got="$(TZ=Europe/Madrid "$st_self" --at 2026-09-22T19:05:00Z 2>&1 | sed -n 3p)"
  if [ "$st_got" = "timeZone=Europe/Madrid" ]; then echo "ok    \$TZ is the default zone"; else
    echo "FAIL  \$TZ is the default zone: got $st_got"; st_fails=$((st_fails + 1)); fi
  st_expect "Etc/UTC is kept" \
    "generatedAtLocal=Tue 22 Sep 2026 · 19:05 Etc/UTC (UTC+00:00)${nl}generatedDateLocal=2026-09-22${nl}timeZone=Etc/UTC" \
    --at 2026-09-22T19:05:00Z --tz Etc/UTC
  for st_meta in zone.tab tzdata.zi +VERSION leapseconds iso3166.tab; do
    st_refuse "database metadata is not a zone: $st_meta" --at 2026-09-22T19:05:00Z --tz "$st_meta"
  done
  st_refuse "an impossible date: 2026-02-30" --at 2026-02-30T12:00:00Z --tz UTC
  st_refuse "an impossible date: 2026-09-31" --at 2026-09-31T12:00:00Z --tz UTC
  st_refuse "a fraction that is not digits" --at 2026-09-22T19:05:00.abcZ --tz UTC
  st_refuse "an empty fraction" --at 2026-09-22T19:05:00.Z --tz UTC
  st_refuse "a fraction with two dots" --at 2026-09-22T19:05:00.1.2Z --tz UTC
  st_refuse "a zone not in zoneinfo" --at 2026-09-22T19:05:00Z --tz Mars/Olympus
  st_refuse "a path, not a zone" --at 2026-09-22T19:05:00Z --tz ../../etc/passwd
  st_refuse "a non-UTC instant" --at 2026-09-22T14:05:00-05:00 --tz America/Bogota
  st_refuse "not an instant" --at yesterday --tz America/Bogota
  st_refuse "no --at" --tz America/Bogota
  st_refuse "an unknown flag" --at 2026-09-22T19:05:00Z --zone UTC
  if [ "$st_fails" -eq 0 ]; then echo "report_time.sh --self-test: all passed"; return 0; fi
  echo "report_time.sh --self-test: $st_fails failed"; return 1
}

self_test
fixture_status=$?
[ "$fixture_status" -eq 0 ] || exit "$fixture_status"
# The legacy CLI still forwards to these same assertions. Re-enter once with the marker set;
# clear only instrumentation for its child fixture, whose own asserted output must stay plain.
if [ "${HATSU_REPORT_TIME_FORWARDER_CHECK:-0}" != 1 ]; then
  forwarded="$(HATSU_REPORT_TIME_FORWARDER_CHECK=1 HATSU_SHELL_COVERAGE_EXEC= "$st_self" --self-test 2>&1)"
  forward_status=$?
  case "$forwarded" in
    *'report_time.sh --self-test: all passed'*) [ "$forward_status" -eq 0 ] || exit 1 ;;
    *) printf 'report-time-fixture: --self-test forwarding failed (exit %s)\n%s\n' "$forward_status" "$forwarded" >&2; exit 1 ;;
  esac
  echo 'report-time-fixture: compatible --self-test forwarding passed'
  # Hatsu is distributed as a Git source tree: the self-test companion ships in scripts/ beside
  # the forwarder. Exercise that installed layout and a standalone renderer without the companion.
  layout_root="$(mktemp -d "${TMPDIR:-/tmp}/hatsu-report-time-layout.XXXXXX")" || exit 2
  trap 'rm -rf "$layout_root"' EXIT
  mkdir -p "$layout_root/plugin/scripts" "$layout_root/standalone"
  cp "$report_time" "$layout_root/plugin/scripts/report_time.sh"
  cp "$script_dir/report_time_fixture.sh" "$layout_root/plugin/scripts/report_time_fixture.sh"
  HATSU_REPORT_TIME_FORWARDER_CHECK=1 HATSU_SHELL_COVERAGE_EXEC= sh "$layout_root/plugin/scripts/report_time.sh" --self-test > "$layout_root/installed.log" 2>&1 || {
    cat "$layout_root/installed.log" >&2; echo 'report-time-fixture: paired plugin-source self-test failed' >&2; exit 1;
  }
  cp "$report_time" "$layout_root/standalone/report_time.sh"
  standalone="$(sh "$layout_root/standalone/report_time.sh" --at 2026-09-22T19:05:00Z --tz UTC)" || exit 1
  [ "$standalone" = "generatedAtLocal=Tue 22 Sep 2026 · 19:05 UTC (UTC+00:00)
generatedDateLocal=2026-09-22
timeZone=UTC" ] || { echo 'report-time-fixture: standalone rendering changed' >&2; exit 1; }
  missing="$(sh "$layout_root/standalone/report_time.sh" --self-test 2>&1)"; missing_status=$?
  case "$missing" in
    *report_time_fixture.sh*) [ "$missing_status" -eq 2 ] || { echo "report-time-fixture: missing companion exited $missing_status instead of 2" >&2; exit 1; } ;;
    *) echo 'report-time-fixture: missing self-test companion was not diagnosed' >&2; exit 1 ;;
  esac
  echo 'report-time-fixture: paired source layout and standalone rendering passed'
fi
