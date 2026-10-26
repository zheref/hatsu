#!/usr/bin/env node
// ledger_findings_prepare.mts — the findings copy a durable slice may publish (mukai § 2 step 8a;
// WORKFLOW § The effort's ledgers, The durable slice; HA-PR-#463 review, SEC-3 and SEC-8).
//
//   node scripts/ledger_findings_prepare.mts --findings <record.json> --repo <checkout> --out <copy.json> [--json]
//
// The slice comment is public wherever the pull request is, and nen posts the findings document
// verbatim (it relativises phases and proof paths, not this document). Two things are decided here,
// before `nen pr ledger post --findings <copy>`:
//   1. HOLD (SEC-3). While any finding of scope `security` and severity `critical` or `high` has a
//      disposition other than `fixed`, nothing is written and the verdict is `security-unsettled`, each
//      such finding's id named: a pointer to an unrotated credential is not published before the rotation.
//   2. RELATIVISE (SEC-8). Every string in the copy has its absolute paths rewritten: the checkout's root
//      (as given and as its real path) to `.`, the user's home to `~`, and any other absolute path under
//      /Users, /home, /private, /var, /tmp or a Windows drive to `<path>`. The record itself is never
//      changed. The copy carries no absolute path afterwards, or the run refuses rather than write it.
//
// exit 0  `prepared` (the copy written) · exit 1  `security-unsettled` (nothing written)
// exit 2  wiring: a missing flag, an unreadable or malformed record, an output that is not absolute
import { readFileSync, realpathSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { isAbsolute, resolve } from 'node:path';

function wiring(message: string): never { console.error(`ledger-findings: ${message}`); process.exit(2); }
const args = process.argv.slice(2);
const flags: Record<string, string> = {};
let json = false;
for (let i = 0; i < args.length; i++) {
  const flag = args[i] as string;
  if (flag === '--json') { json = true; continue; }
  const value = args[i + 1];
  if (!['--findings', '--repo', '--out'].includes(flag) || value === undefined || value.startsWith('--')) wiring(`unknown or incomplete argument '${flag}'`);
  flags[flag.slice(2)] = value as string;
  i++;
}
for (const key of ['findings', 'repo', 'out']) if (flags[key] === undefined) wiring(`--${key} is required`);
if (!isAbsolute(flags.out as string)) wiring('--out must be an absolute path');

let record: { findings?: unknown };
try { record = JSON.parse(readFileSync(flags.findings as string, 'utf8')); } catch (error) { wiring(`${flags.findings}: could not read (${(error as Error).message})`); }
if (typeof record !== 'object' || record === null || !Array.isArray(record.findings)) wiring(`${flags.findings}: not a findings record (no findings[])`);

type Finding = { id?: unknown; scope?: unknown; severity?: unknown; disposition?: { state?: unknown } };
const unsettled = (record.findings as Finding[]).filter((f) => f?.scope === 'security' && (f.severity === 'critical' || f.severity === 'high') && f.disposition?.state !== 'fixed');
if (unsettled.length > 0) {
  const ids = unsettled.map((f) => String(f.id));
  if (json) console.log(JSON.stringify({ contract: 'hatsu.ledger-findings/v0.1', verdict: 'security-unsettled', ids }));
  else console.log(`security-unsettled: ${ids.join(', ')} -- a security finding of severity critical or high is not fixed; the slice is not posted`);
  process.exit(1);
}

const repo = resolve(flags.repo as string);
const roots = [...new Set([repo, (() => { try { return realpathSync(repo); } catch { return repo; } })()])].sort((a, b) => b.length - a.length);
const home = homedir();
const escape = (text: string): string => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const OTHER = /(?:\/(?:Users|home|private|var|tmp)\/[^\s"'`)\]]*|\b[A-Za-z]:\\[^\s"'`)\]]*)/g;
function relativise(text: string): string {
  let out = text;
  for (const root of roots) out = out.replace(new RegExp(`${escape(root)}(?=/|$|[^A-Za-z0-9._-])`, 'g'), '.');
  if (home !== '/' && home !== '') out = out.replace(new RegExp(`${escape(home)}(?=/|$|[^A-Za-z0-9._-])`, 'g'), '~');
  return out.replace(OTHER, '<path>');
}
function walk(value: unknown): unknown {
  if (typeof value === 'string') return relativise(value);
  if (Array.isArray(value)) return value.map(walk);
  if (value !== null && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, walk(v)]));
  return value;
}
const copy = walk(record);
const text = `${JSON.stringify(copy, null, 2)}\n`;
if (/\/(?:Users|home|private|var|tmp)\//.test(text)) wiring('an absolute path survived relativising; nothing written');
writeFileSync(flags.out as string, text, { mode: 0o600 });
if (json) console.log(JSON.stringify({ contract: 'hatsu.ledger-findings/v0.1', verdict: 'prepared', out: flags.out }));
else console.log(`prepared: ${flags.out} -- ${(record.findings as unknown[]).length} finding(s), absolute paths relativised`);
