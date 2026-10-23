# Ruling records

One file per recorded picker answer that settles a ruling: `<R-id>.json`, the `nen.stop.answer/v0.1`
record exactly as `nen stop answer show <effort> --json` returned it, copied here by
`node scripts/ruling_record.mts export` so a reviewer holds the bytes its ROSTER row is rendered from.

- Written by `export` only, never by hand, never replaced: a second export of the same id with other
  content is refused.
- Each record is cited by exactly one ROSTER row, rendered by `node scripts/ruling_record.mts render`;
  the `ruling-record` lane re-renders every citing row and reports a difference by HR id, and a record
  no row cites is a finding ([`ROSTER.md`](../ROSTER.md) § *The ruling template*, step 3).
- The procedure that writes the record at the picker is [`WORKFLOW.md`](../WORKFLOW.md) § 4 *Every
  picker answer is recorded* (zheref/hatsu#443). Private names are placeheld before the record is
  written ([`PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md)); the redaction tree check reads this
  directory like every other tracked file.
