### Added

- The Hatsu desk on Claude Code: a function-hook module (`hooks/desk`, named under `modules` in
  `hooks/hooks.json`) that opens a pane beside the chat in any checkout declaring `nen/workflow.json`.
  It shows where this session's effort stands in the canon and every path the maintainer can take
  from it, open paths first and the ones still waiting dimmed with their reason; each button fills
  the prompt with the skill call and sends nothing, and the merge, `kagutsuchi` and `mugetsu` are
  never a button. It also lists the session's activity, the gate stops `nen stop list` names, and
  the other efforts in the shared phase ledgers with their worktree, branch and PR state.
  `/hatsu-desk` reopens it; its tests run on the new `desk-guard` lane.
