# Agent attribution

**Prospective commits carry the canonical agent attribution that truthfully identifies the responsible
persona or autonomous plane.** Use `Hatsu-Agent: <persona>` for Hatsu work and
`Akatsuki-Agent: <persona>` only for autonomous Akatsuki work. Never infer a persona from a runtime alias
or stamp a default persona when it was not responsible. `Co-Authored-By`, `Claude-Session`, model,
surface/runtime/session, `Signed-off-by`, and "Generated with" attribution are forbidden in commit messages
and bodies. Author and committer metadata preserve the actor's configured identity. Earlier commits and
dated evidence records are historical and are not rewritten.

The pull request body also ends with this final section:

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
