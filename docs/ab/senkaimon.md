# A/B evidence — `senkaimon` (zheref/hatsu#577)

`claude/skills/senkaimon/SKILL.md`: a consumer's open PRs tried one head at a time on a device, the
queue shown first, one authorization for the target and the core swap and launch, each merge-or-revise
call tied to the tested head and the actual target, and core returned at the end. **This file holds
the read-only probes run when the skill landed and the protocol SC-1 still owes.** A stale probe is a
finding: the date is part of the record.

## 1. Read-only probes — 2026-11-10

**Run: 2026-11-10 (UTC), nen `0.30.0` at `/Users/zheref/.local/bin/nen`, host `darwin` (arm64), from the
working tree of `opus/kurapika/ha-577-pr-review-queue` over base `691865a36`, against `zheref/hatsu`
itself** (a read target only: nothing below swapped, launched or wrote outside this clone's object
database).

### The invocation

```
$ nen parse senkaimon --grammar "<repo> [--target <target>]" --line "FI --target iphone"
repo: FI
target: iphone
exit=0

$ nen parse senkaimon --grammar "<repo> [--target <target>]" --line ""
nen parse: <repo> is required and the line does not supply it.
exit=2
```

### The queue and one row's head (§ 2)

`nen repo inventory --target zheref/hatsu --epic-label epic --integration-prefix integration/ --trunk
main --json` returned six `openPrs`, each `{number, title, baseRefName, url, isDraft}` — **no head and no
fork flag**, which is why the skill adds the named read:

```
$ node scripts/gh_api_read.mts pr-head zheref/hatsu 576
{"baseRef":"main","baseRepo":"zheref/hatsu","draft":false,"head":"94a01e4480536b4ce38dc8c03c946ccf90bc10fb","headRef":"opus/kurapika/ha-574-resume-proof-parse","headRepo":"zheref/hatsu","number":576,"state":"open","title":"fix(resume-proof): read the run manifest from the verb's json answer"}
```

`headRepo` equals `baseRepo`: not a fork. The `gh-api-read-guard` lane pins the fixed GET path and the
projection, and refuses a hostile PR number or an extra flag before `gh` runs.

### The head brought in, and the declaration read (§ 4 step 2)

```
$ nen wc worktree --repo . --name senkaimon --base main --dry-run
worktree:        /Users/zheref/Code/Agents/hatsu/.nen/worktrees/senkaimon (would create)
head:            691865a36a6e60bb6479a569badfb7dfcb916310
exit=0

$ git fetch origin refs/pull/576/head
 * branch                refs/pull/576/head -> FETCH_HEAD
$ git merge-base origin/main 94a01e4480536b4ce38dc8c03c946ccf90bc10fb
691865a36a6e60bb6479a569badfb7dfcb916310
$ git diff --name-only 691865a36a6e60bb6479a569badfb7dfcb916310 94a01e4480536b4ce38dc8c03c946ccf90bc10fb -- nen/contract.json nen/workflow.json
(no output: eligible)
```

**Not run here**: the worktree created for real, the swap, the launch, the verdict pickers, the merge
prompt and the return. Each moves the maintainer's core checkout or a device and needs § 3's answer.

## 2. Owed — the SC-1 proof run (zheref/hatsu#580)

On one consumer with a declared physical-device target and a declared simulator target, and at least
two open PRs, the maintainer runs `hatsu:senkaimon <CODE>` attended and this file records, dated:

| # | Case | Shows |
|---|---|---|
| 1 | the queue before any checkout; an empty queue reads "No open PRs." | AC-1 |
| 2 | one PR launched on the physical device, its build, install and launch evidence | SC-1, AC-2 |
| 3 | one PR launched on the simulator | SC-1, AC-2 |
| 4 | **Send to merge gate** with the head unmoved: en § 5's prompt pinned to the tested head | AC-3 |
| 5 | **Send to merge gate** after a push moved the head: pending, the reason, retry or defer | AC-3, AC-5 |
| 6 | **Request revision**: the brief written, the queue continued, the revised head relaunched | AC-4 |
| 7 | the device absent with a declared fallback: requested and actual target both named | AC-5 |
| 8 | the device present but locked: the `on-device-act` stop, then the retry | AC-5 |
| 9 | a failed install: untested at that head, retry · defer · stop | AC-5 |
| 10 | a fork head and a head changing `nen/contract.json`: both ineligible with their reasons | AC-5 |
| 11 | a stop with uncommitted work in core: `nen wc swap --return` restores it, `--status` reads no swap | AC-6 |
| 12 | a `dev` child still running when the next PR is reached: the build waits | AC-7 |
