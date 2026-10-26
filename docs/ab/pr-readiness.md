# Evidence — the `pr-readiness` JSON verdict (zheref/hatsu#131)

This record closes the evidence gap left after the readiness JSON reader was implemented. It changes no
reader, workflow, template or Tenkai source, and it makes no claim that the observed pull request was
Ready. The live verdict below was `not-ready`; the acceptance fact is that the check title and Nen's JSON
`verdict` were equal for the same judged head.

## Dated live proof — 2026-10-25

Observed at `2026-10-25T19:30:25Z`, against HA-PR-#463 at head
`2853d07ba9c593190c598391ddb2c5a0cc2e6b16`.

### The two-step landing

The trusted-policy change landed before the workflow installation, in the order the trusted guard
requires:

| Order | Delivery | Merged (UTC) | Evidence |
|---:|---|---|---|
| 1 | [HA-PR-#327](https://github.com/zheref/hatsu/pull/327), `ci(readiness): admit trusted JSON verdict reader` | `2026-10-20T13:53:51Z` | Source commit `71d558094`: added the reader, its fixture and the guard's admitted next shape; the live workflow still used the prior shape. |
| 2 | [HA-PR-#328](https://github.com/zheref/hatsu/pull/328), `ci(readiness): install trusted JSON verdict reader` | `2026-10-20T17:49:56Z` | Source commit `537b51873`: changed Hatsu's workflow and Tenkai template to execute `.trusted/scripts/readiness_ci_verdict.mts`, and added the Tenkai reader/render checks. |

There is no source implementation delta in this evidence-only follow-up.

### The published check

The live check was read directly by id:

```console
$ gh api repos/zheref/hatsu/check-runs/120729982672 --jq \
    '{id,name,head_sha,status,conclusion,started_at,completed_at,details_url,title:.output.title,summary:.output.summary}'
{
  "id": 120729982672,
  "name": "readiness",
  "head_sha": "2853d07ba9c593190c598391ddb2c5a0cc2e6b16",
  "status": "completed",
  "conclusion": "success",
  "started_at": "2026-10-24T00:47:25Z",
  "completed_at": "2026-10-24T00:47:25Z",
  "details_url": "https://github.com/zheref/hatsu/runs/120729982672",
  "title": "not-ready",
  "summary": "Verdict: not-ready\nJudged head: 2853d07ba9c593190c598391ddb2c5a0cc2e6b16\nchecks-green (CON-32(a)): failed — \"not-ready: required checks reported but are not all green (CON-32a)\""
}
```

Check id `120729982672` therefore published title `not-ready` on the exact head named above. Its
`success` conclusion is the workflow's advisory transport result, not a Ready verdict; the title and
summary carry the readiness result.

### Nen's same-head JSON verdict

Run from the Hatsu checkout, with the workflow run and every prior `readiness` check excluded exactly as
the trusted reader does:

```console
$ nen pr ready 463 --gh-repo zheref/hatsu --json \
    --gates "$PWD/nen/gates.json" \
    --exclude-run 40046678172 \
    --exclude-check readiness \
    --require-head 2853d07ba9c593190c598391ddb2c5a0cc2e6b16
{
  "contract": "nen.pr.ready/v0.1",
  "verdict": "not-ready",
  "failing": ["mergeable"],
  "judgedHead": "2853d07ba9c593190c598391ddb2c5a0cc2e6b16",
  "meta": {
    "excludeRun": "40046678172",
    "requiredHead": "2853d07ba9c593190c598391ddb2c5a0cc2e6b16",
    "excludedChecks": ["readiness"],
    "evaluatedAt": "2026-10-25T19:30:29Z",
    "generator": {"program": "nen", "version": "0.26.0"}
  }
}
exit 1
```

Exit `1` is Nen's `not-ready` result. The machine-readable comparison is exact:

| Object | Head | Verdict/title |
|---|---|---|
| Published `readiness` check `120729982672` | `2853d07ba9c593190c598391ddb2c5a0cc2e6b16` | `not-ready` |
| `nen.pr.ready/v0.1` document | `2853d07ba9c593190c598391ddb2c5a0cc2e6b16` | `not-ready` |

## Acceptance-criterion mapping

| zheref/hatsu#131 criterion | Durable evidence |
|---|---|
| Workflow and template consume `nen pr ready --json`, including verdict, failing rows and judged head | `scripts/readiness_ci_verdict.mts` validates `nen.pr.ready/v0.1`, its verdict, `failing`, conjuncts and `judgedHead`; both workflow forms invoke that trusted reader. Covered by HA-PR-#327 and installed by HA-PR-#328. |
| Trusted-guard change lands first, workflow change second, with fixtures | HA-PR-#327 merged before HA-PR-#328; the former admitted and exercised the next frozen step, the latter installed it. |
| Tenkai renders the new template shape and self-tests the JSON read | HA-PR-#328 added the Tenkai reader transport, render gate and assertions for the trusted reader path, event head and copied source arguments. |
| One live PR's `readiness` title equals the JSON verdict | HA-PR-#463 at the recorded head: check `120729982672` title `not-ready` equals the same-head Nen JSON verdict `not-ready`. |

## Versioning and changelog

No plugin manifest bump or generated-surface restamp belongs to this record. `docs/ab/**` is deliberately
outside `scripts/plugin_bump_check.sh`'s installed-plugin surface because installed copies never read these
human-facing evidence files. No changelog fragment is added: this follow-up records already-delivered
behaviour and introduces no runtime, canon or installed-surface change.
