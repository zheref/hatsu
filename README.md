# Hatsu

A Claude Code plugin for driving repository-centric, agentic delivery from your terminal: a lead persona (**Kurapika**, with six declared work-modes) and a roster of focused independents, whose skills replace improvised shell with deterministic verbs from the [Nen](https://github.com/zheref/nen) CLI.

> **Status: pre-release (private).** Hatsu ships early in the Akatsuki migration and serves the live [bankai-core](https://github.com/zheref/bankai-core) system before its successor exists. This repo goes public at **v0.1**, with a full README, license, and marketplace install instructions.

The contract (ratified in the migration plan):

- **Hard dependency on Nen** — fail-closed with auto-install: skills run the checksum-verified bootstrap themselves and halt with the exact command only if that fails. No LLM-improvised fallback for Nen-owned operations, ever.
- **Minimum-version range** — `nen >= X.Y`, checked at warm-up; backward-compatible within a major.
- **Same skill names** — the 17 skills port under their existing names; only their mechanics change.
