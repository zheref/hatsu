# Ruling records

One file per recorded picker answer that settles a ruling: `<effort>--<R-id>.json`, the
`nen.stop.answer/v0.1` record `nen stop answer show <effort> --json` returned, re-serialized two-space
with exactly the record's own keys by `node scripts/ruling_record.mts export`, so a reviewer holds the
content its ROSTER row is rendered from.

- **An R-id is evidence, never a ruling id.** HR-2 stands: a ruling is cited by its `HR-{n}` row. A
  reviewer may cite an `R-…` record as a ruling only before its row lands (the review preamble § 3).
- **A record comes from the clone that took the ruling.** nen counts `R-YYYY-MM-DD-nn` per git common
  directory, so two clones can mint one id; the effort in the file name keys it, and `check` refuses a
  file whose effort and id disagree with its name.
- **Written by `export` only**, which refuses a copy that differs and a record that names a private
  repository or holds a secret-shaped string; `check` does not detect a record and its row edited together
  by hand, so a reviewer compares the record with `nen stop answer show` in the clone that took it.
- Each record is cited by exactly one ROSTER row, rendered by `node scripts/ruling_record.mts render`;
  the `ruling-record` lane re-renders every citing row and reports a difference by HR id, and a record
  no row cites is a finding ([`ROSTER.md`](../ROSTER.md) § *The ruling template*, step 3).
- **A row has two inputs: its record and `nen/repos.json`.** `render` codes a `<repository> #N` in the
  question, an option or the picked label as `<owner>/<name>#N` when `nen repo resolve` names one
  repository, never the maintainer's typed words; the record keeps the words as shown. So `render` and
  `check` need nen on PATH, a registry change can change how a landed row re-renders (the lane runs on
  it), and `render` passes each coded slug through the private-name guard, since a code names a
  repository the exported text may never have held.
- The procedure that writes the record at the picker is [`WORKFLOW.md`](../WORKFLOW.md) § 4 *Every
  picker answer is recorded* (zheref/hatsu#443). The redaction tree check reads this directory with JSON
  string escapes decoded ([`PUBLIC-REDACTION.md`](../PUBLIC-REDACTION.md)).
