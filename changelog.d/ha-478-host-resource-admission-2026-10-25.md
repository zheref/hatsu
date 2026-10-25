### Added

- `docs/WORKFLOW.md` § *Host workload budget — heavy local work*: the host workload budget, distinct from effort/worktree capacity (`nen loop slots --local-cap`) and remote-provider quotas; what counts as heavy; the missing admission guard (owed to zheref/nen#536–#540), reported by every heavy phase as `host admission: no guard (zheref/nen#536); serialized fallback`; the documented serialized fallback (one heavy workload at a time across the session, its delegates and same-host CI, the orchestrator holding the heavy turn, `nen runner inventory` for same-host runners with unknown read as busy, a finite worker count of 2 unless a brief names another, a pending heavy lane never green); stop on overload and retry only after a descendant listing shows quiescence and the host's recovery is observed, else `parked:g5-host-overload`; no stopped claim without descendant evidence and no kill by name or pattern. Closes #478.
- The host block every delegate brief carries word for word (`<!-- delegate-host:begin -->` … `end`), beside #473's wait block. Its mechanical check beside `scripts/delegate_brief_check.mts` is owed (unfiled).
- `claude/rules/hatsu.md` rule 11 (every mirrored surface) and `claude/agents/kurapika.md` § *The `shu` verbs* (Codex AGENTS.md) carry the same obligations; `docs/PROCESS.md` names the residue and the heavy-verb turn in § *Running a declared verb*.

### Changed

- WORKFLOW § *The local build, and the concurrency cap* and § *Idle batches* rule 4: a free slot admits no heavy launch; seven open efforts do their heavy work one at a time.
- kazaana § 3 hands the delegate the wait and host blocks; futon §§ 4 and 6 cite the blocks and the host budget.
- Prose-diet trims to fit: kazaana § 3 drops the rules-file pointer to the Antigravity `Workspace` adapter (rules rule 6 and WORKFLOW § *Where worktrees live* still carry it); futon § 6 drops the slot-source clause it restated from WORKFLOW § *Idle batches* rule 4; `claude/rules/hatsu.md` § *Never* folds its restatements of rules 5, 6, 7 and 8 into pointers to them (each rule is unchanged).
