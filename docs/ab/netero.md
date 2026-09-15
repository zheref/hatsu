# Evidence — `netero` (new independent, Hatsu 0.25.0)

`claude/agents/netero.md`: the process chairman. He observes Hunters in execution and files
complete, labelled issues when constitution, canon prose, or machinery need enhancement.

**This is not a port.** There is no retired skill behind it. The protocol composes
[`hatsu:file`](../../claude/skills/file/SKILL.md) and [`docs/DISCOVERY.md`](../DISCOVERY.md); what
is new is standing, completeness, and owner routing.

**Run:** 2026-09-14, `nen 0.10.0`, host Darwin. No issue was filed in this session — the definition
lands so the chairman can be acted as. Constructed completeness below; live filing is the first
real `hatsu:file` under this protocol.

---

## 1. Standing

| Fact | Where |
|---|---|
| Ratified independent, not a bench activation, not a provision | `docs/ROSTER.md` § *Rulings of 2026-09-14* |
| Listed in `plugin.json` `agents` | `.claude-plugin/plugin.json` |
| Deep tier, effort high, `model: opus` | frontmatter; Cursor maps deep → grok |
| Writer for process-chairman class | `docs/DISCOVERY.md` Capture and ownership |
| Files; never implements the filed work | agent hard limits |

## 2. Completeness contract (constructed)

A chairman issue that shipped without labels, without observable acceptance criteria, or without
owner routing would be the failure this definition exists to prevent. The required body slots:

1. Problem in one sentence
2. Sanitized evidence
3. Why it matters, and to whom
4. Observable acceptance criteria (never invented to fill the shape)
5. Scope boundaries
6. Cross-references in the target's object notation — constitution/skill section, siblings,
   **deployment**, **fan-out**, **provisioning**
7. Every *declared* classifying label from the target's `nen/labels.json`, applied in the create
   call. Hatsu currently has no severity family — none is invented.

Owner is decided before the write: Hatsu for workflow and skill prose, Nen for shared
deterministic machinery. Separate, cross-linked issues; never folded across owners.
**Third-Hand** (`v0.27.0`) is the wrap-up harvest: 0–3 folded proposals of similar same-owner
problems, filed only after the maintainer picks.

## 3. Observation classes

Duration · redundancy · autonomy gap · determinism (improvised shell that should be a Nen verb) ·
toolchain · other roster friction. One finding, one issue in execution. Third-Hand may fold
similar same-owner problems into at most three wrap-up proposals.

## 4. What this session did not do

Did not file a live issue as Netero. Did not invent Hatsu severity labels. Did not implement a
filed fix. Nen-owned operations stayed on Nen verbs.
