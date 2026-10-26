# Agent attribution

**Prospective commits carry the canonical agent attribution that truthfully identifies the responsible
persona or autonomous plane.** Use `Hatsu-Agent: <persona>` for Hatsu work and
`Akatsuki-Agent: <persona>` only for autonomous Akatsuki work. Never infer a persona from a runtime alias
or stamp a default persona when it was not responsible. `Co-Authored-By`, `Claude-Session`,
`Signed-off-by`, `Generated-by`, `Generated-with`, `Reviewed-by`, model, surface/runtime/session, and
"Generated with" attribution are forbidden in commit messages and bodies. Author and committer metadata
preserve the actor's configured identity. Earlier commits and
dated evidence records are historical and are not rewritten. This rule is canon as **`CON-51(c)`** in
[`zheref/bankai-handbooks`](https://github.com/zheref/bankai-handbooks)' `CONSTITUTION.md` (handbook set
v0.6): a commit carries the truthful canonical plane/persona trailer for the responsible actor — never a
model, surface, runtime, session or "generated-with" attribution, and never a `Co-Authored-By:` naming an
AI assistant.

Hatsu's required PR `check` reads `commits.forbiddenTrailers` over every PR commit, including a commit made outside Kokusen.

Consumers that merge a Tenkai adoption rendering `.github/workflows/forbidden-commit-trailers.yml`
carry the separate `forbidden-commit-trailers` check. Existing consumers do not receive it until their
own adoption PR lands. The job scans every commit in `base.sha..head.sha`, including merge side
history, using `commits.forbiddenTrailers` from the exact base commit. It runs on hosted Ubuntu
under `pull_request_target` with `contents: read` and `checks: write`, no persisted checkout credentials,
and no execution of PR-controlled code. Tenkai copies `scripts/consumer_trailer_ci.mts` into the
consumer alongside the workflow; only that publisher from the exact base checkout runs with the
check-writing token. It fetches the numeric `refs/pull/<number>/head` from the base repository's fixed HTTPS URL into a
new temporary bare Git store, verifies the fetched SHA against the event head, and never checks out
PR files. Only that fetch receives an ephemeral authentication header in its child environment;
Git reading, download and range-reader subprocesses receive no GitHub token. No credential is
persisted. A missing or malformed policy, unavailable object, or failed reader download or digest
check fails the job.

The reader is Hatsu's existing `scripts/branch_authorship_check.sh --forbidden-only`, pinned to
published v0.142.0 commit `16ff11b07b69305cf6a420972ca3d3926b44be67`, SHA-256
`d7cbb1dd4c6d8d5ff472b96922c5f5d3eda7fdcd69ea8e485becbfe8629e0da8`. Nen v0.28.0 has no
forbidden-trailer range verb; the released script already checks body lines, case-insensitive keys
and every range commit, so this adoption reuses its reviewed implementation. The template verifies
the digest before executing it. The trusted publisher creates a check on the event's exact PR head,
then completes that returned check ID. It verifies the response's head SHA, `github-actions` producer,
workflow-ref/run/attempt external identity, details URL and persisted conclusion; it never finds or
trusts a check by name alone. API failure or identity mismatch cannot produce a successful job.

Explicit publication follows GitHub's [check-run API](https://docs.github.com/en/rest/checks/runs#create-a-check-run),
which identifies the target commit through `head_sha`. GitHub's [required-check troubleshooting](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)
requires the latest SHA and supports selecting the expected App. The `trailer-policy-runner` workflow
job provides diagnostics; the required check is the explicitly published `forbidden-commit-trailers`.
Cancellation or setup failure can prevent a replacement verdict; it does not invalidate an earlier
check on the same head. This workflow does not implement a `merge_group` queue check.

After the Hatsu release, each repository in `nen/repos.json` → `consumers` needs its own Tenkai
adoption PR at G2. Run `scripts/tenkai_adopt.sh diagnose --repo <consumer> --json`, then apply in that
consumer's isolated effort. A consumer with a workflow policy guard must first land registration
that admits the actual proposed workflow; Tenkai probes that guard and stages a refused rendering.
There is no two-step requirement for a consumer without such a guard. This change does not adopt
any other repository or edit its rulesets.

Before enabling a required-check rule, adopt both the workflow and
`scripts/consumer_trailer_ci.mts` on every protected destination branch it covers, and scope the
ruleset to those adopted branches. The retarget regression covers adopted bases. Retargeting into
a pre-adoption branch does not invalidate an earlier success on the same head: an absent workflow
or base publisher cannot publish a replacement verdict, so that earlier check may remain.

Once the adoption PR has landed and the job has run successfully, the consumer maintainer adds
`forbidden-commit-trailers` under **Settings → Rules → Rulesets → the protected base branch rule →
Require status checks to pass → Add checks** (or the corresponding branch protection rule).
Select the check with that exact name and bind its expected source to the **GitHub Actions** App and require the branch to be up to date.
Tenkai installs the workflow; the maintainer owns the required-check rule. The advisory readiness
job does not replace this failing check. Set `includeCoAuthoredBy: false` as described in [WORKFLOW.md](WORKFLOW.md) to stop the Claude Code harness from injecting that trailer.

The pull request body begins with `## Delivery`, rendered from the effort's Nen phase, usage and session ledgers. It reports role, surface, recorded model with registry alias, effort dial, session and a ledger locator. The public Source cell gives kind/index, timestamp and optional phase; free-form ledger provenance stays local. An exact served model ID appears only when the harness reported and the ledger recorded it; an alias alone never proves an ID. An unread ID or session is stated explicitly. This is PR delivery provenance, not commit attribution. The pull request body also ends with this final section:

```markdown
## Agent attribution

| Agent | Canonical persona / plane | Role and contribution | Evidence |
|---|---|---|---|
| Happy | kurapika | Coordinated scope and verified the final change | PR commits and checks |
```

The table lists **only agents that actually participated**. `Agent` is the participant's known display
name; `Canonical persona / plane` is the roster identity responsible for the contribution. Do not add
model, surface, runtime, or session attribution; neither display name nor canonical persona is inferred
from one. A participant without a canonical persona records `none — no Hatsu persona assigned` alongside
their known agent name, actual contribution, and evidence; never invent a persona.

The PR author owns the ledger. It records each participant's role, concrete contribution, and
reviewable evidence (commit, check, review, or explicitly named artifact). It does not list
delegated agents that did no work, prospective reviewers, or a default persona merely because it
opened the PR. The section remains final so the PR body has one auditable participant record.
