# A/B evidence — Tenkai publishing adoption (HA#475)

## Scope and status

This record separates the compatibility fixture shipped in HA-PR-#491 from execution of an
actual deployed consumer Hanten gate. The fixture in `scripts/pr_sections_fixture_check.ts`
is a compatibility contract, and its own comment explicitly disclaims actual consumer execution.
It does not establish HA#475/SC-1 by itself.

**Observed on 2026-10-26:** the actual fresh Tenkai route ran, and the same derived body passed
both real guards with zero script edits. All five positive/negative cases matched their expected
exits. The recovered script remained byte-identical and all five production source hashes were
unchanged. Source: Hatsu commit `fa77a3c705dafbdd8a64dbea3a9572cfccaa3cea`; catalogue SHA-256
`ddc28165475067b2bf5fe4e4ff1f7f4fafdc3602ac596679c0fda6f25c3eedc3`. The experiment exercises publishing
configuration and PR-body templates after the actual Tenkai diagnose/apply route in a fresh
scratch consumer. Outstanding consumer-policy and lane configuration rows remain visible;
this does not certify trusted-base readiness, CI registration, or a two-step bootstrap landing.

## Actual gate provenance

The recovered deployed script has Git blob SHA-1
`77228a3e97013a9c4e0cef92c9802ea93d40fb56`, rechecked with `git hash-object` before preparing
this experiment. It accepts a PR body through `PR_BODY` or stdin, reads no repository configuration,
and makes no network request or GitHub write. The private recovery record retains the source
provenance. Consumer identity and source code are deliberately absent from this public record.
The original recovered bytes are used directly; no copy or substitute validator is committed here.

## Fresh publishing experiment

The local evidence driver prepares a new scratch Git repository with regular fixture declarations:
`project.kind: product`, a registry entry for `fixture-owner/ha475-scratch`, and a nonempty
`commits.forbiddenTrailers` policy so the trailer workflow can render. The labels and gates fixture
declarations are empty objects. These are explicit scratch inputs, not assertions of complete
schema-valid application configuration. No consumer policy guard is installed, so no registration
prerequisite is bypassed. The driver then calls the full production adopter:

```bash
bash "$hatsu_root/scripts/tenkai_adopt.sh" diagnose --repo "$scratch_consumer" --slug fixture-owner/ha475-scratch --visibility public --self-hosted 0 --json
```

```bash
bash "$hatsu_root/scripts/tenkai_adopt.sh" apply --repo "$scratch_consumer" --slug fixture-owner/ha475-scratch --visibility public --self-hosted 0 --json
```

```bash
bash "$hatsu_root/scripts/tenkai_adopt.sh" diagnose --repo "$scratch_consumer" --slug fixture-owner/ha475-scratch --visibility public --self-hosted 0 --json
```

The explicit visibility and zero self-hosted count bypass both GitHub probes in the production
context loader. No runner labels are supplied, so the online-label probe is also unreachable.
The production wrapper invokes `config_values.sh fill --refresh` itself before the frozen adopter.
The proof retains every adopter item, its exact outstanding count, and all routed consumer choices.
It asserts that colors, the readiness reader, readiness workflow, and trailer workflow were repaired
or satisfied by the production route, rather than copied into the scratch fixture by the driver.

Before and after adoption, it reads publishing configuration through:

```bash
bash "$hatsu_root/scripts/config_values.sh" diagnose --repo "$scratch_consumer" --domain publishing --json
```

The adopter's `fill` writes defaults across the catalogue, not only the publishing domain:
`--domain` filters `diagnose`, not `fill`. The evidence retains the full apply result and any
outstanding items. A zero publishing diagnosis is not a zero Tenkai adoption diagnosis. The proof
checks that the written `pr.sections` stamp matches the packaged catalogue and its options name Hanten.

The driver resolves the product/implementation body through the actual resolver, reads each
selected block from its shipped `templates/pr-body/` file, substitutes the product verification
title, and fills the Hanten findings row with a reason and the existing HA#475 issue URL. These
are normal body composition changes. It changes neither guard script. The same complete body
then reaches both guards:

```bash
bash "$hatsu_root/scripts/pr_sections_resolve.sh" --repo "$scratch_consumer" --kind product --jobs implementation --out "$requirements"
```

```bash
bash "$hatsu_root/scripts/pr_body_sections_check.sh" --body "$body" --requirements "$requirements" --max 7
```

```bash
bash "$recovered_deployed_gate" < "$body"
```

The observed matrix is below. The asymmetric cases identify the boundary each guard owns.

| Body case | PR-sections expected exit | Deployed Hanten expected exit | Observed |
|---|---:|---:|---|
| Exact registered H2, tracked deferred row, checked settled line | 0 | 0 | Matched |
| Replace Hanten H2 with an undeclared heading | 1 | 1 | Matched |
| Decorate Hanten H2 with a glyph | 1 | 1 | Matched |
| Remove the deferred row's only tracked item | 0 | 1 | Matched |
| Uncheck the settled checklist line | 0 | 1 | Matched |

The driver records argv, stdout, stderr, exit status and signal for every command; asserts the
written defaults and resolver output; hashes production source before and after; and compares
the recovered gate bytes before and after. A timeout or unexpected status stops it. No command
opens a PR, edits a consumer checkout, or contacts GitHub. The local artifacts remain private;
only sanitized results and hashes belong in this record after execution.

## Source reading and acceptance boundaries

Fresh source reading found the bootstrap rule, the link to *The two-step landing* in
`docs/GATE-CONFIGURATION.md`, and the withheld `unevaluated` verdict in all three named skills:

| Skill | Source section | HA#475 criteria |
|---|---|---|
| `tenkai` | § 5d | AC-1, AC-2, AC-4 |
| `mukai` | § 2 preflight and bootstrap paragraph | AC-1, AC-2, AC-4 |
| `en` | § 4 bootstrap paragraph and terminal handoff | AC-1, AC-2 |

Thus SC-2 has source-reading evidence (3 of 3); AC-1, AC-2 and AC-4 were already implemented.
AC-3 and SC-1 passed the fresh-adoption experiment above: both real guards accepted the same
body with zero hand edits to either script.
The actual Tenkai route and Hatsu's shipped artifacts are available; there is no missing consumer
bundle preventing that experiment. The deployed consumer's unchanged body gate is sufficient for
its half of SC-1 because it consumes only the body, not repository configuration. A successful
experiment can establish fresh scratch adoption passing both guards with zero script edits while
still reporting unrelated Tenkai configuration gaps. It cannot establish that a first onboarding
PR is Ready; SC-1 does not require that distinct claim.

## Observed adoption outcomes

| Production command | Exit | Observed result |
|---|---:|---|
| Initial publishing diagnosis | 1 | Defaults not yet adopted |
| Initial Tenkai diagnosis | 1 | Adoption work reported |
| Actual Tenkai apply | 1 | Templates rendered; 3 routed items retained |
| Follow-up Tenkai diagnosis | 1 | Same 3 routed items retained |
| Follow-up publishing diagnosis | 0 | Publishing configuration satisfied |
| Production requirements resolver | 0 | Requirements matched the production in-process resolution |

The adopter reported these outstanding items, without treating exit 1 as a crash or a pass:

| Item | State | Outstanding prerequisite |
|---|---|---|
| `hooks/commit-msg` | routed | Nen must generate the commit hook from the consumer policy; Tenkai does not write it |
| `workflow/review-scopes` | routed | Consumer chooses review scopes, personas, paths and budgets |
| `config/needed` | routed | Required `workflow.review.scopes` has no default |

`config/needed` also offered seven nonblocking values: `workflow.profile.default`,
`workflow.release.unitPaths`, `workflow.runners`, `gates.approval_policy`, `gates.reviewers`,
`contract.project.targets`, and `contract.project.launch`. The driver did not answer them.
Colors, the readiness reader, readiness workflow and trailer workflow were each reported repaired
or satisfied and asserted before checking the body. No consumer review was performed: the finding
row is controlled experiment data, and the deployed gate attests the body's settled record only.

The evidence ran serially in recorded process group `59279` (PID equals PGID). The completed group
had no remaining processes when inspected. Local private transcripts retain every argv, stdout,
stderr, status and the unchanged source hashes; no private consumer identity or gate code is
published. Kokusen/Aka verification and publication are separate from this adoption proof.
