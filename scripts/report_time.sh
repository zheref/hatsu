#!/bin/sh
# report_time.sh — say a report's UTC instant in the time zone the report is generated for.
#
#   scripts/report_time.sh --at <ISO-8601 UTC instant> [--tz <IANA zone>]
#   scripts/report_time.sh --self-test
#
# `nen report data` and `nen board build` stamp `generatedAt` as an absolute ISO-8601 UTC instant,
# and that instant stays the document's truth. A maintainer reading the page reads a clock, though,
# and a UTC stamp late in their evening names tomorrow's date. This prints the same instant in the
# zone the report is for, so the page can show it readable and keep the UTC value in <time datetime>.
#
# The zone, in order: --tz (the caller passes `reports.timeZone` from nen/workflow.json here when it
# is set); else a non-empty $TZ; else the host's /etc/localtime; else UTC. An IANA name that is not
# in the zoneinfo database is REFUSED rather than passed to `date`, which would silently answer UTC.
# "In the database" means a compiled zone: a file whose first four bytes are `TZif`. The database
# directory also holds tables and metadata (zone.tab, tzdata.zi, +VERSION, leapseconds, iso3166.tab)
# that `date` cannot use as a zone, and each of them is refused the same way.
#
# The instant is refused when it names a date that does not exist (2026-02-30): the parsed epoch is
# turned back into a UTC stamp and must equal the input, because BSD date(1) rolls an impossible day
# into the next month rather than failing. A fraction of a second is `.` and digits, nothing else.
#
# Output, one `key=value` per line, for the caller to merge into the data document:
#   generatedAtLocal=Tue 22 Sep 2026 · 14:05 America/Bogota (UTC-05:00)
#   generatedDateLocal=2026-09-22      <- the <YYYY-MM-DD> of a dated report's file name
#   timeZone=America/Bogota
#
# exit 0  printed
# exit 2  refused, with the reason on stderr — an unknown zone, an instant that is not UTC or
#         does not parse, a missing or unknown argument

usage() {
  echo "usage: report_time.sh --at <ISO-8601 UTC instant> [--tz <IANA zone>]" >&2
  echo "       report_time.sh --self-test" >&2
}

zoneinfo_has() {  # zoneinfo_has <zone>
  case "$1" in
    UTC|Etc/UTC) return 0 ;;
    ''|/*|*..*) return 1 ;;
  esac
  for zdir in /usr/share/zoneinfo /var/db/timezone/zoneinfo; do
    [ -f "$zdir/$1" ] || continue
    [ "$(dd if="$zdir/$1" bs=4 count=1 2>/dev/null)" = "TZif" ] && return 0
  done
  return 1
}

host_zone() {
  if [ -n "${TZ:-}" ]; then
    printf '%s\n' "${TZ#:}"
    return
  fi
  link="$(readlink /etc/localtime 2>/dev/null)"
  case "$link" in
    */zoneinfo/*) printf '%s\n' "${link##*/zoneinfo/}" ;;
    *) printf 'UTC\n' ;;
  esac
}

to_epoch() {  # to_epoch <YYYY-MM-DDTHH:MM:SS> — read as UTC
  if date -u -d '@0' +%s >/dev/null 2>&1; then
    date -u -d "$(printf '%s' "$1" | tr 'T' ' ')" +%s 2>/dev/null
  else
    date -j -u -f '%Y-%m-%dT%H:%M:%S' "$1" +%s 2>/dev/null
  fi
}

in_zone() {  # in_zone <zone> <epoch> <format>
  if date -u -d '@0' +%s >/dev/null 2>&1; then
    TZ="$1" LC_ALL=C date -d "@$2" "$3"
  else
    TZ="$1" LC_ALL=C date -r "$2" "$3"
  fi
}

render() {  # render <instant> <zone>
  at="$1"; zone="$2"
  if ! zoneinfo_has "$zone"; then
    echo "report_time.sh: '$zone' is not a zone in this host's zoneinfo database; refusing rather than let date(1) answer UTC" >&2
    return 2
  fi
  case "$at" in
    *Z) core="${at%Z}" ;;
    *+00:00) core="${at%+00:00}" ;;
    *) echo "report_time.sh: '$at' is not a UTC instant (it must end in Z or +00:00)" >&2; return 2 ;;
  esac
  frac=""
  case "$core" in
    *.*) frac="${core#*.}"; core="${core%%.*}"
      case "$frac" in
        ''|*[!0-9]*) echo "report_time.sh: '$at' has a fraction that is not digits (it must be .[0-9]+)" >&2; return 2 ;;
      esac ;;
  esac
  case "$core" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]) ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9])
      [ -z "$frac" ] || { echo "report_time.sh: '$at' has a fraction with no seconds" >&2; return 2; }
      core="$core:00" ;;
    *) echo "report_time.sh: '$at' is not an ISO-8601 instant (YYYY-MM-DDTHH:MM[:SS[.fff]]Z)" >&2; return 2 ;;
  esac
  epoch="$(to_epoch "$core")"
  if [ -z "$epoch" ]; then
    echo "report_time.sh: date(1) could not read '$at'" >&2
    return 2
  fi
  back="$(in_zone UTC "$epoch" +%Y-%m-%dT%H:%M:%S)"
  if [ "$back" != "$core" ]; then
    echo "report_time.sh: '$at' names a date or time that does not exist (it reads back as ${back}Z)" >&2
    return 2
  fi
  day="$(in_zone "$zone" "$epoch" +%d)"; day="${day#0}"
  clock="$(in_zone "$zone" "$epoch" '+%a DAY %b %Y · %H:%M')"
  offset="$(in_zone "$zone" "$epoch" +%z)"
  offset="$(printf '%s' "$offset" | sed 's/^\([+-]\)\([0-9][0-9]\)\([0-9][0-9]\)$/\1\2:\3/')"
  printf 'generatedAtLocal=%s %s (UTC%s)\n' "$(printf '%s' "$clock" | sed "s/DAY/$day/")" "$zone" "$offset"
  printf 'generatedDateLocal=%s\n' "$(in_zone "$zone" "$epoch" +%Y-%m-%d)"
  printf 'timeZone=%s\n' "$zone"
}

# ---------------------------------------------------------------------------
# --self-test — hermetic and offline: fixed instants, fixed zones, nothing written.
# ---------------------------------------------------------------------------
self_test() {
  st_fails=0
  st_self="$0"
  st_expect() {  # st_expect <label> <expected output> [args...]
    st_label="$1"; st_want="$2"; shift 2
    st_got="$(sh "$st_self" "$@" 2>&1)"; st_rc=$?
    if [ "$st_rc" -eq 0 ] && [ "$st_got" = "$st_want" ]; then
      echo "ok    $st_label"
    else
      echo "FAIL  $st_label (exit $st_rc)"; echo "      want: $st_want"; echo "      got:  $st_got"
      st_fails=$((st_fails + 1))
    fi
  }
  st_refuse() {  # st_refuse <label> [args...]
    st_label="$1"; shift
    st_got="$(sh "$st_self" "$@" 2>&1)"; st_rc=$?
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
  st_got="$(TZ=Europe/Madrid sh "$st_self" --at 2026-09-22T19:05:00Z 2>&1 | sed -n 3p)"
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

at=""; tz=""
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) self_test; exit $? ;;
    --at) [ $# -ge 2 ] || { usage; exit 2; }; at="$2"; shift 2 ;;
    --tz) [ $# -ge 2 ] || { usage; exit 2; }; tz="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "report_time.sh: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done
[ -n "$at" ] || { echo "report_time.sh: --at is required" >&2; usage; exit 2; }
[ -n "$tz" ] || tz="$(host_zone)"
render "$at" "$tz"
