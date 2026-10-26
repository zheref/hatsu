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

<!-- Every kind (HR-11): one row per AC id of each issue this PR closes (its Closes lines, or the
Development sidebar on the default branch), Criterion written <CODE>#<N>/AC-<k>, <k> the id as the
issue writes it ({n}, or Akatsuki's {epic}-{nnn}; zheref/hatsu#411); Coverage one of
satisfied · partial · missing · contradicts · unrequested; Evidence a test name, path:line or
scenario. nen pr converge judges the table. No closing issue: drop this table. -->

| Criterion | Coverage | Evidence |
|---|---|---|
| <CODE>#<N>/AC-<k> | <satisfied · partial · missing · contradicts · unrequested> | <test name, path:line or scenario> |
