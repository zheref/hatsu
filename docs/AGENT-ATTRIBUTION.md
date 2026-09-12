# Agent attribution

**Prospective Hatsu commit messages contain no agent, plane, runtime-name, or model attribution.**
`Hatsu-Agent`, `Akatsuki-Agent`, `Co-Authored-By`, `Claude-Session`, `Signed-off-by`, and
"Generated with" lines are all forbidden. The git author remains the human. Earlier commits and
dated evidence records are historical and are not rewritten.

Attribution belongs in the pull request body, as its final section:

```markdown
## Agent attribution

| Canonical Hatsu persona | Role and contribution | Evidence | Runtime alias / model |
|---|---|---|---|
| kurapika | Coordinated scope and verified the final change | PR commits and checks | Happy / gpt-5.6-terra |
```

The table lists **only agents that actually participated**. `Canonical Hatsu persona` is the
roster identity responsible for the contribution. A surface's display name, runtime alias, and
model are optional context; none substitutes for the canonical persona, and none is an
attribution claim in a commit. A participant without a canonical persona is recorded as
`none — no Hatsu persona assigned`, with the actual contribution and evidence; never invent a persona.

The PR author owns the ledger. It records each participant's role, concrete contribution, and
reviewable evidence (commit, check, review, or explicitly named artifact). It does not list
delegated agents that did no work, prospective reviewers, or a default persona merely because it
opened the PR. The section remains final so the PR body has one auditable participant record.
