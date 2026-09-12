# Shared launch resolution and consumer migration

Hatsu #48 owns the workflow contract. Nen #204 owns record extraction in the existing
`nen shu dev/run --target` machinery. Hatsu #49 owns capture and reconciliation of new gaps.
The consumer owns its concrete build, installation and launch commands. These are linked
changes, not three copies of the same implementation.

## Availability and release boundary

[Nen v0.9.0](https://github.com/zheref/nen/releases/tag/v0.9.0) publishes the implementation of
[Nen #204](https://github.com/zheref/nen/issues/204) from [PR #206](https://github.com/zheref/nen/pull/206),
released at the merge of [PR #208](https://github.com/zheref/nen/pull/208). Its three binaries and
SHA256SUMS are published. Hatsu's adoption sets `minimum: "0.9"` and `pinned_ref: "v0.9.0"`;
Nen 0.8.0 does not execute `device.extract`. The new release keeps compatibility floor 0.7 for
consumers that retain older declarations, which is separate from the feature minimum.
Verify the installed binary accepts the extraction declaration before changing a consumer.
Retain KroApple's normalizer until its declaration migration and successful physical build,
install and launch; publishing the shared replacement is not consumer-device proof.
Hatsu #49 must be addressed and validated before considering a new Hatsu tag. No tag or release
is authorized by this migration guide.

## Record ownership

A probe describes devices; the extraction declaration identifies the device record boundary and
maps its name, canonical identifier and readiness value. Repeated descriptive names within one
record remain one device. Two distinct records with the same selected name remain ambiguous.
Selection stays exact, and readiness is never inferred from presence. Malformed output is a
refusal, not an empty successful inventory. Nen spawns only commands in the consumer declaration.

| Platform | Declaration responsibility | Shared resolver responsibility |
|---|---|---|
| Apple | Declare devicectl JSON probe, physical-platform lane, install and launch after-steps | Read one record per `result.devices` entry; select the logical identifier and supported readiness paths without counting nested aliases as devices |
| Android | Declare an appropriate text/JSON probe and native build/install/launch commands | Extract the declared record fields, preserve exact selection and reject missing/unusable readiness; only declared header/line handling applies |
| Expo | Select the iOS or Android native lane and its platform probe and artifact | Use the corresponding Apple/Android extraction; no Expo-only resolver or implicit tool command |

The exact schema and runnable examples are maintained with Nen's implementation in `docs/USAGE.md`
and `docs/STACK-MATRIX.md`. Check those against the installed release; do not copy an unreleased
key into an older consumer and hope it is ignored. Existing targets without extraction preserve
their documented behavior until migrated.

## KroApple sequence

KroApple commit `718d3766` records the temporary `ci_scripts/nen_apple_devices.py` normalizer and
`ci_scripts/test_nen_apple_devices.py`. The normalized probe plus the physical build lane reportedly
completed build/install/launch; that issue evidence is not a device run by this Hatsu change.

1. Retain the working normalizer and its focused test while the shared replacement is unreleased.
2. After the compatible release is published, update the consumer's pin as required by its
   compatibility verdict and use a probe/extraction declaration supported by that binary.
3. Inspect the target-specific lane: the build platform is physical iOS, the installed artifact is
   that build's app, and both install and launch after-steps are declared.
4. Through Nen, prove synthetic record tests and the applicable checkpoint checks. Run the full
   regression in aka and extraction-only coverage in mukai; do not turn migration into a hidden
   early full-suite or coverage run.
5. From the maintainer's core checkout, read the target's declared `verb` and run
   `nen shu <declared-dev-or-run-verb> --repo <core-checkout> --target iphone`.
   Record build, installation and launch results separately. A dry run is not delivery. Preserve
   the temporary fallback until the replacement is verified; remove the two Python files and the
   probe-only test row as part of the verified consumer migration. If device proof is unavailable,
   report the migration pending and retain the fallback.
6. Regenerate Hatsu surface mirrors with `nen surface mirror generate` from canonical source.
   Refresh consumer skills through Hatsu's supported surface bootstrap/warm-up installation;
   regenerate inherited rules through that consumer's declared Nen canon synchronization workflow.
   Never hand-edit `.agents/skills/` or `.claude/rules/` generated copies.

The consumer's testing/coverage declarations must also separate instrumented regression collection
from extraction. Bankai's testing, completion and screenshot source rules remain an upstream owner
change preserving UZF-19/UZF-26; consumer generated rules cannot repair their own source.

## Reviewable outcomes

| Case | Required outcome |
|---|---|
| One record repeats its name and carries two identifier aliases | One selected record and its declared canonical identifier |
| Two records carry the same exact name | Refuse before build or installation |
| Device is present but unauthorized/offline | Report unusable; never apply absent-device fallback |
| Device is absent | Use only configured fallback, or report disconnected with no launch |
| Output is malformed or readiness is missing | Refuse honestly; no successful empty inventory or implicit ready state |
| Device target builds a simulator artifact | Declaration defect; no successful physical-device delivery claim |
| Build succeeds but install/launch fails | Report the failed step and incomplete delivery |
| No app target exists (Hatsu/Nen tooling) | Explicit no-launch skip |

These are acceptance scenarios. Synthetic execution belongs to Nen #204's tests; actual device
execution belongs to the consumer migration. This document does not claim either ran merely
because a row describes its expected outcome.
