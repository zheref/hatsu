# Discovery ledger — 2026-09-12

| Owner / item | Result | Evidence and disposition |
|---|---|---|
| Hatsu #48 | Existing scope | Phase boundaries, physical artifact delivery, and shared launch ownership; user follow-up adds checkpoint-focused tests and pre-squash lint |
| Hatsu #49 | Existing scope | Standing discovery protocol and real tool-repository metadata; no stage labels invented |
| Nen #204 | Existing scope | Shared record extraction; independent review defects repaired inside this authorized implementation, not filed again |
| [Nen #205](https://github.com/zheref/nen/issues/205) | Created | Four passes found no related issue; whole-body updates have no conditional write guarantee. Narrow dependency recorded, not implemented as part of #204 |
| [Bankai #895](https://github.com/zheref/bankai-core/issues/895#issuecomment-5647669282) | Updated | Existing completion-boundary issue received material phase evidence and Rules 07/12/16 synchronization requirements; inspected body and comments; no open PR; no new duplicate |
| KroApple migration | Pending filing / release | Four-pass search found only unrelated #481 in documentation lane; its body/comments inspected, no open PR. Consumer `nen/labels.json` and `nen/repos.json` are absent. Retain this sanitized record until owner metadata and compatible Nen release permit recovery |

## KroApple pending record

- Timestamp: 2026-09-12; owner: zheref/KroApple.
- Affected paths: nen/contract.json, nen/workflow.json, .claude/CLAUDE.md, ci_scripts/nen_apple_devices.py, ci_scripts/test_nen_apple_devices.py; inherited generated rules require upstream source correction.
- Evidence: current apple.test collects instrumented .nen/test.xcresult. apple.coverage deletes that bundle and reruns the entire suite before extraction. apple-device.test is focused on the temporary Python probe. iphone now selects apple-device with install and launch after-steps.
- Required consumer work: declare scoped authored tests, make coverage extraction-only with tree/configuration provenance, align completion language, migrate device.extract only after compatible released Nen, then retire both Python files and their focused test row after successful physical build/install/launch.
- Workaround/removal: retain the currently working normalizer until the published Nen #204 replacement is accepted by the installed binary and verified on the configured device. No personal names or identifiers are recorded here.
- Search: Nen four passes ran successfully on subject, closed subject, files, documentation lane. #481 is consent wording, not the phase/launch migration. No matching migration issue was found. Filing was not attempted with fabricated target metadata.
- Recovery: verify consumer origin and live labels; obtain its owner-approved Nen registry/taxonomy; rerun all four searches and inspect issue bodies/comments/open PRs; file one narrow migration item or update an existing one. Never recurse into issues about unavailable filing.
- Original objective: Hatsu/Nen implementation continues. Consumer mutation and physical-device proof remain downstream of a compatible published release. No tag is cut by this run.


## Implementation verification

Nen prerequisite PR: https://github.com/zheref/nen/pull/206, head
`3e75e10cf524af9ac025c4dd89a3df6f4f36e1cb`. Its 4,503-test aka regression passed; matching
JUnit was parsed without execution and mukai coverage validated the saved LCOV without a second
suite. Touched executable lines: schema/contract 98.18%, shu/launch 98.66%, shu/render 96.88%,
shu/run 99.03%. Test, JSON and Markdown paths are not instrumented. Independent Sol review
findings were corrected and rechecked.

Formal CON-32 readiness remains a separate configuration fact: `nen pr ready` refuses on Nen's
missing reviewer identities (`nen/gates.json` absent). The Hatsu reference gates file describes a
frozen different repository and is not an authoritative substitute. Do not invent reviewers or
report this refusal as Ready; CI and local review outcomes remain independently reportable.


## Follow-up steering

The maintainer supplied the reviewer set: Copilot and zheref only. Both repositories now record
it in `nen/gates.json`; the earlier missing-identities refusal above is historical. Human approval
is still required and no review is cast by this run.

[Nen #207](https://github.com/zheref/nen/issues/207) was created after four-pass reconciliation for
reusable focused selection, and material details were added to Hatsu #48. The current static-lane
mechanism is not a shipped dynamic selector. The related KroApple task was informed directly;
its Python probe lane is not evidence for focused Swift behavior.
