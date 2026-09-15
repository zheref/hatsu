# Evidence — `third-hand` (new skill, Hatsu 0.27.0)

`claude/skills/third-hand/SKILL.md`: En's session-closing harvest. Netero reads the sitting in
parallel with the retained final report, proposes 0–3 folded process issues, the maintainer picks
which to file through the surface picker, Netero files only those, then the sitting is over.

**This is not a port.** There is no retired skill behind it. Filing still composes
[`hatsu:file`](../../claude/skills/file/SKILL.md) and [`docs/DISCOVERY.md`](../DISCOVERY.md);
what is new is the wrap-up trigger, the parallel summon, the 0–3 cap, and session-over.

**The merge is still not a skill.** G2 remains an action no agent performs. Third-Hand wraps the
sitting; it does not describe, propose, or wait for the merge.

**Run:** 2026-09-15, `nen 0.10.0`, host Darwin. No issue was filed as the harvest of *this*
authoring sitting — the skill lands so En can start it. Parse verified live below. Live harvest
is the first real En terminus under this protocol.

---

## 1. Standing

| Fact | Where |
|---|---|
| Workflow skill, atomic, session-close of `ren → aka → mukai → en` | `claude/skills/README.md` |
| Started by En after the retained final report; also directly invocable | `claude/skills/en/SKILL.md` § 3 step 8 |
| Netero raised as `third-hand · netero · <model alias>`, never frontier | `claude/agents/netero.md`; hanten § 4's model-pin rule reused |
| Codex has no in-session subagent — protocol in the foreground | `docs/SURFACES.md` § 1 |
| Files; never implements; never merges | skill hard limits; Netero's |

## 2. Verbs exercised live

### 2.1 — `nen parse third-hand`: the same anchored optional clause En uses

```
$ nen parse third-hand --grammar "on [<ref>]" --line "on HA#62"
ref: HA#62
exit=0

$ nen parse third-hand --grammar "on [<ref>]" --line "on"
ref: (clause absent)
exit=0

$ nen parse third-hand --grammar "on [<ref>]" --line ""
ref: (clause absent)
exit=0
```

Recorded 2026-09-15 against nen `0.10.0`. **No clause means this sitting.** En starts the skill
without parsing, for the same reason it does not parse Mukai's handoff.

### 2.2 — owner resolve still refuses a guess

`nen repo resolve` is `file`'s, not this skill's. Exit `0` is the slug; exit `1` the token is not
a repo; exit `2` there is no registry. Third-Hand names that split and does not re-derive it.

## 3. What this session did not do

Did not harvest the authoring sitting as if En had already closed it — this effort is still
open. Did not file a live chairman issue from a simulated wrap-up. Did not merge. Did not
implement a filed fix. Did not invent a harvest verb; the marker is named residue.
