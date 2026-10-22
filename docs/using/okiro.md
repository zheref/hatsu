# Starting a new project with Okiro

Run `hatsu:okiro --stack <id>` in an empty directory. Okiro asks for the missing project inputs,
shows one complete plan and executes it on one confirmation. `--name <project>` supplies the name;
`--dry-run` previews without writing files, installing dependencies or changing host settings.
The installed surface respells the invocation as the table in [the guide](README.md) describes.

The stack picker is read from the installed `nen scaffold --help`, so it follows the adopted
packs. Nen 0.24 has fresh-tree templates for Expo, Gatsby and Next.js. Its native stacks return
an exact manual instruction; Okiro quotes that refusal before writing and names
[NN#470](https://github.com/zheref/nen/issues/470), the structured native-handoff dependency.
After a manual native project creation, use `hatsu:tenkai` to adopt the existing tree.

The template supplies the toolchain slice. Package-manager pins, framework dependencies and
scripts and required minimal starter files are resolved in the plan from official stack
documentation; Okiro adds no custom product feature or generator. The proposed default is
`kind: product`, `role: consumer`, visible and changeable.
The intended GitHub slug is an input for local readiness configuration; supplying it creates no
repository. Approver identities and other policy choices belong to the owner.

## What the confirmation covers

The plan names the generated files, setup commands, dependencies, hook policy, declaration seeds,
Tenkai repairs/defaults and local surface files. It translates Nen's printed early commit into
`git init` now and the sole commit after verification. The initial branch is a topic branch so
the generated trunk guard remains effective. The policy's local base ref is created at the same
initial commit for the first later Ren effort; no existing ref is moved. Okiro then switches
to that new base and verifies final adoption there, where no active effort ledger is due.

Before the first commit, HEAD and the base do not exist. Okiro proves that unborn state and
compares the actual symbolic topic branch with the configured base instead of invoking the
normal history-dependent classifier. It keeps the other Kokusen gates, including the actual
declared iteration checks. The generated default runs a real build; a build preview is not
a passing build and missing starter source is not concealed by a seat or a weakened check.

Local adoption composes `nen scaffold new`, the approved post-steps, `nen scaffold init` and
`hatsu:tenkai`. Missing taxonomy is authored from the approved owner answers and validated by
Nen, rather than copied from Hatsu's own repository. The plan shows that explicit bootstrap
residue. A schema FAIL, a withheld build seat, a missing tool or an unsatisfied Tenkai row is
reported with its owner and remedy. An external policy registration or label sync is offered
separately; Okiro cannot call the project fully verified while it remains required and pending.

After native prebuild, Expo can have native lanes beside the original Expo lane. Detection
and `scaffold init --accept-detected` use the same complete proposal. Consumer-specific
customizations follow strict initialization; `--stack expo` would narrow the proposal and
make the declaration collide with itself.

The official setup references, read on 2026-10-21, are
[Next.js installation](https://nextjs.org/docs/app/getting-started/installation),
[Expo project creation](https://docs.expo.dev/get-started/create-a-project/) and
[Gatsby quick start](https://www.gatsbyjs.com/docs/quick-start/). Resolve versions and template
contents again when planning; do not run their floating `latest` examples without pinning the
chosen input. If an official generator is needed to obtain template files, its scratch
destination, disabled/removed generated Git history, files copied and exact merge of this
run's overlapping setup files must all appear in the plan. Never run it over the occupied
Nen target or import a second initial commit. Foreign files always stop.

Verification records `nen schema check`, `nen shu tools`, a resolving `nen shu build --dry-run`,
Ten's actual adoption rows and one initial commit carrying `Hatsu-Agent: Kurapika`.
Resolving the build command does not claim the framework has built a product that does not exist yet.

## Resuming safely

Okiro records the approved plan and phase outcomes. The journal initially lives in a private
scratch directory outside the target, preserving Nen's empty-tree check; its path is reported
before scaffolding. It moves to ignored `.nen/okiro/` after the fresh tree exists. If interrupted
before the move, identify that exact scratch journal to the resumed run.

`hatsu:okiro --resume` checks actual owned-file hashes and Git history before skipping a seam.
A new session confirms the remaining plan if the original approval cannot be established.
Changed files, an absent journal or an uncertain generator outcome stop for inspection. It never
cleans the directory, retries a destructive generator or adds a second initial commit. Running the
ordinary command in any non-empty directory refuses and points to `hatsu:tenkai`.

At the end, repository creation, a first issue (`hatsu:emperor-time` / `hatsu:file`) and the first
effort (`hatsu:ren`) are offers. Okiro has no create-remote or push flag.
