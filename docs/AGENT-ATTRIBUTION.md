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

**Where the PR-level check exists, and where it does not.** In `zheref/hatsu`, the required
`check` that the `plugin-bump-check` workflow publishes includes a *Forbidden commit trailer guard* step, which runs the trusted revision's
`scripts/branch_authorship_check.sh --forbidden-only` over every PR commit from the base, a commit made
outside Kokusen included. **A consumer repository has that check only where its own workflow runs
one**: `hatsu:tenkai` renders no forbidden-trailer job yet, and `nen` has no verb that reads a commit
range against `commits.forbiddenTrailers`, so a consumer's guard today is Kokusen's and Aka's read-back
plus, where `nen scaffold init` stood it up, its `commit-msg` hook. Never report a consumer's PR check
as present without reading that repository's workflow. Installing one is that repository's own pull
request at G2, never an edit made from here. Set `includeCoAuthoredBy: false` as described in
[WORKFLOW.md](WORKFLOW.md) to stop the Claude Code harness from injecting that trailer.

## Cursor cloud agents: no documented off-switch

Fetched 2026-10-25 from Cursor's own documentation. The cloud-agent page
<https://cursor.com/docs/cloud-agent/security-network> (§ *Commit author*) says:

> "On GitHub, Cloud Agents author and commit as `Cursor Agent <cursoragent@cursor.com>`, not as the
> person who started the agent."
>
> "When Cursor can look up the person who started the agent, it adds them to each commit as a
> `Co-authored-by` trailer. Agents started by service accounts, such as automations, don't get that
> trailer."

**No Cursor page fetched that day documents a setting that turns that trailer off.** The documented
attribution switch, <https://cursor.com/help/integrations/git>, covers the `Made with Cursor` trailer
("When Agent creates commits or pull requests, Cursor can add a `Made with Cursor` trailer
automatically"; "Toggle it in **Cursor Settings** > **Agent** > **Attribution**"), and the CLI's
`attribution.attributeCommitsToAgent` (<https://cursor.com/docs/cli/reference/configuration>) is
described as "Add "Made with Cursor" trailer to Agent commits". The Enterprise admin toggle on the same
help page ("no trailers are appended to Agent commits or PRs across the organization") names neither
cloud agents nor `Co-authored-by`, so it is **not** claimed to reach them. The only documented condition
under which a cloud agent's commit lacks the trailer is an agent started by a service account; whether
to run cloud agents that way is the maintainer's decision, not a setting a skill applies. A cloud agent
therefore stamps `Co-authored-by` on **every** commit, which `commits.forbiddenTrailers` refuses.

## A hook that re-injects on every commit

The recovery is a **stop before the first push**, never publish and disclose (zheref/hatsu#470).
`nen commit write` and `nen wc squash` read each commit back and exit `3` on an injected key;
[`kokusen`](../claude/skills/kokusen/SKILL.md) § 5 and [`aka`](../claude/skills/aka/SKILL.md) § 4 drop the
unpublished tip once and ask for the switch. **If the re-run reads the key back again, no switch reached
the hook**: drop the tip, keep the change, push nothing, and stop at **G5** with `nen stop`. Aka § 7's
pre-push guard (`--forbid-trailers-from`) refuses an outgoing range carrying a forbidden key, so the
first publish never sends one. `--no-verify` is never the way around the hook, and a commit already
published is never rewritten by a run (row `rewrite-published-history`; the maintainer's alone). The
maintainer's options are to move the effort to a surface whose harness appends nothing (row
`harness-attribution-switch`, option B) or to leave it stopped.

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
