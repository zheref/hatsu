# Agent attribution

**Prospective commits carry the canonical agent attribution that truthfully identifies the responsible
persona or autonomous plane.** Use `Hatsu-Agent: <persona>` for Hatsu work and
`Akatsuki-Agent: <persona>` only for autonomous Akatsuki work. Never infer a persona from a runtime alias
or stamp a default persona when it was not responsible. `Co-Authored-By`, `Claude-Session`, model names,
surface/runtime/session names, `Signed-off-by`, and "Generated with" lines are forbidden in commit messages
and bodies. Author and committer metadata preserve the actor's configured identity. Earlier commits and
dated evidence records are historical and are not rewritten.

Attribution belongs in the pull request body, as its final section:

```markdown
## Agent attribution

| Canonical persona / plane | Role and contribution | Evidence |
|---|---|---|
| kurapika | Coordinated scope and verified the final change | PR commits and checks |
```

The table lists **only agents that actually participated**. `Canonical Hatsu persona` is the
roster identity responsible for the contribution. Do not add model, surface, runtime, or session context;
none substitutes for the canonical persona. A participant without a canonical persona is recorded as
`none — no Hatsu persona assigned`, with the actual contribution and evidence; never invent a persona.

The PR author owns the ledger. It records each participant's role, concrete contribution, and
reviewable evidence (commit, check, review, or explicitly named artifact). It does not list
delegated agents that did no work, prospective reviewers, or a default persona merely because it
opened the PR. The section remains final so the PR body has one auditable participant record.
