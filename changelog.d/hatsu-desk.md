### Added

- The Hatsu desk on Claude Code: a function-hook module (`hooks/desk`, named under `modules` in
  `hooks/hooks.json`) that opens a pane beside the chat in any checkout declaring `nen/workflow.json`.
  It shows where this session's effort stands in the canon and every path the maintainer can take
  from it, open paths first and the ones still waiting dimmed with their reason; each button fills
  the prompt with the skill call and sends nothing, and the merge, `kagutsuchi` and `mugetsu` are
  never a button. It also lists the session's activity, the gate stops `nen stop list` names, and
  the other efforts in the shared phase ledgers with their worktree, branch and PR state.
  `/hatsu-desk` reopens it; its tests run on the new `desk-guard` lane.
- Two maintainer rulings for the desk in `docs/ROSTER.md` (Governance 1.61.0): HR-370, a button
  that only fills a human-only call (`aka`, `mukai`, `tensho`) into the prompt is the maintainer's
  own typed call, never an agent's offer; HR-371, the wrap-up buttons show only once every PR in
  the sitting reads merged, naming the satisfied declaration as still owed.
- Before a PR exists the desk reads Preparing PR, Reviewing while hanten's reviewers run, or
  Remediating while their findings are settled, and the merge gate only from the stop En records at Ready.
- When GitHub reads the open PR as conflicting with its base, the desk says so and stars Update
  (`murasaki`), which merges the base in and stops on a semantic conflict; Unblock PR only names it.
