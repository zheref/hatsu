<!-- block: verify; Product: numbered steps. Library: Consumer scenario/Call or import/Expected, plus published artifact command. Process: Behavior changed/Lane or verb run/Refuses on/Passes on. Every kind: one Criterion row per AC id of each closing issue (HR-11). -->
## ✅ {{verify_title}}

<!-- Product title: How to verify; numbered manual steps including expected results.
Library title: How a consumer verifies; one row per touched public symbol:
| Consumer scenario | Call or import | Expected |
|---|---|---|
| <scenario> | <call> | <result> |
Also quote the command actually run against the published artefact; an unrun command is unverified.
Process title: What the guards prove; name each fixture in this table: -->

| Behaviour changed | Lane or verb run | Refuses on | Passes on |
|---|---|---|---|
| <behaviour> | <actual command and fixture> | <bad input> | <good input> |

<!-- Every kind (HR-11): one row per AC id of each closing issue in Associated issues, Criterion
written <CODE>#<N>/AC-<k>; Coverage exactly one of satisfied · partial · missing · contradicts ·
unrequested (unrequested only on a row whose Criterion is none: a change no criterion asked for);
Evidence a test name, path:line or scenario. scripts/pr_criteria_check.mts refuses a missing row,
missing or contradicts. No closing issue: drop this table. -->

| Criterion | Coverage | Evidence |
|---|---|---|
| <CODE>#<N>/AC-<k> | <satisfied · partial · missing · contradicts · unrequested> | <test name, path:line or scenario> |
