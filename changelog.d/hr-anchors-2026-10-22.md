### Changed

- **Every older ruling in `docs/ROSTER.md` carries an HR id (HR-2).** The sections before the SDD sitting take HR-42 to HR-324 in document order, each ruling row, numbered ruling or ruling paragraph with a status: `ruled`, `reading` where the file marks this run's reading or unruled, or `reversed by` / `superseded by` the HR row the file already records. No ruling's words change. The five bare-date section titles take their first subsection's topic, so no two titles are the same. A new § *Readings* indexes every reading-status clause with its date and the gate it awaits, and a governance footer states the version rule.

### Added

- **`scripts/clause_id_guard.mts`, lane `clause-guard`.** Ported from Akatsuki's clause-id guard: HR definitions are counted and citations never, a duplicated id or a disagreeing anchor exits 1, a gap is a notice, a tooling failure exits 2, and HR-2 never matches HR-20. Its fixture runs fourteen cases, the last over the live roster. Plugin bumped to 0.131.2.
