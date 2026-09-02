# Hatsu

A Claude Code plugin for driving repository-centric, agentic delivery from your terminal: a lead persona (**Kurapika**, with six declared work-modes) and a roster of focused independents. Its skills **will** replace improvised shell with deterministic verbs from the [Nen](https://github.com/zheref/nen) CLI — that port is [#2](https://github.com/zheref/hatsu/issues/2); what ships today is the roster, the manifests and the dependency contract that makes the port possible.

> **Status: pre-release (private), `v0.0.1`.** Hatsu ships early in the Akatsuki migration and serves the live [bankai-core](https://github.com/zheref/bankai-core) system before its successor exists. This repo goes public at **v0.1**, with a full README, license, and marketplace install instructions.

## What exists today

The plugin skeleton, the roster, and the Nen dependency contract — the bring-up half of the migration plan's P2 card. **The seventeen ported skills are not here yet**; they land at [#2](https://github.com/zheref/hatsu/issues/2), which needs Nen's full verb surface.

```
.claude-plugin/                    marketplace.json + plugin.json (plugin name: hatsu)
claude/agents/                     kurapika · gon · hisoka · phinks · uvogin
claude/commands/kurapika.md        the /kurapika summon surface
claude/skills/hatsu-warmup/        the dependency contract, executed
docs/ROSTER.md                     the full roster, including what is still OPEN
docs/delegation-grammar-DRAFT.md   Gon's clause — DRAFT, ratified elsewhere
nen.contract.json                  the machine-readable D10 contract
```

The skill surface deliberately houses those two **roster-machinery** residents rather than being literally empty — declared, with reasons, in [`claude/skills/README.md`](claude/skills/README.md). Neither is one of the seventeen ported skills, and the reservation for those still holds.

- **[Kurapika](claude/agents/kurapika.md)** leads, naming one of six Nen-type work-modes in every reply — Enhancer (product code) · Conjurer (canon & governance) · Transmuter (machinery) · Manipulator (GitHub-side ops) · Emitter (release & fan-out) · Specialist (product intake).
- **[Gon](claude/agents/gon.md)** is the mission-scoped trusted delegate. His delegation grammar is a **draft**, so **he crosses no gate** — see [`docs/delegation-grammar-DRAFT.md`](docs/delegation-grammar-DRAFT.md).
- **[Hisoka](claude/agents/hisoka.md)** reviews UI/UX and measures quality *before* a PR is posted; **[Phinks](claude/agents/phinks.md)** runs adversarial pre-release QA on proven findings; **[Uvogin](claude/agents/uvogin.md)** measures the fixed seven performance metrics.
- **Illumi, Killua and the Genei Ryodan bench are recorded as OPEN** in [`docs/ROSTER.md`](docs/ROSTER.md) — proposals, not rulings.

No agent here has a GitHub App or a bot identity. They run on your own credentials, they never merge `main`, and they never cast a review vote.

## The contract (ratified in the migration plan)

**[`nen.contract.json`](nen.contract.json) is the single source of truth.** Every version, ref and command echoed anywhere else — this README included — is a convenience copy of a value that lives there; where a copy disagrees, the contract wins and the copy is the bug.

- **Hard dependency on Nen** — fail-closed with auto-install: the warm-up installs the pinned build itself and halts with the exact command only if that install fails. No LLM-improvised fallback for Nen-owned operations, ever.
- **Version range** — *current pin, echoed for convenience:* `nen >= 0.1`. **While nen's line is `0.x` that means `>=0.1.0 <0.2.0` exactly** — a different minor is out of range in **both** directions, because at major zero the minor is SemVer's breaking-change vehicle. "Backward-compatible within a major" applies from `1.0` onward.
- **Two install paths** — nen **absent** → run nen's published `bootstrap/nen.sh` (the sole chicken-and-egg carve-out for shell); nen **present but out of range** → re-pin through the verb, `nen bootstrap --ref … --script …`.
- **Fetch to a file, never `curl … | bash`** — the script reads `${BASH_SOURCE[0]}` under `set -u` and dies when piped.
- **The bootstrap is never vendored** — Hatsu fetches nen's own published script at the pinned ref, so there is no second, unreviewed copy to drift.
- **Same skill names** — the 17 skills port under their existing names; only their mechanics change.

## Installing locally

```sh
claude plugin marketplace add /path/to/hatsu
claude plugin install hatsu@hatsu
```

There is no `LICENSE` file yet — licensing is an open maintainer decision, resolved before this repo goes public.
