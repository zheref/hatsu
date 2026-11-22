# The bankai-fleet roster

[`registry.json`](registry.json) is the one roster of every in-scope maintained zheref repository
(zheref/hatsu#620). Repins and the weekly alignment review read from it which repositories to include.
It holds three fields per row and nothing else.

| Field | What it holds | Where the value comes from |
|---|---|---|
| `repo` | `owner/name`, rows sorted case-insensitively | the inventory: every maintained zheref repository in Fuegoleon's Engineering Hub section of 2026-11-21, minus the exclusions the maintainer ruled that day |
| `stack` | a handbook scenario id (`swiftui-tca-uzf-v2`, `compose-uzf-v2`, `react-uzf-v1`, `bankai-machinery`, `nextjs`) or, where the repository declares none, a framework label (`swift`, `swift-package`, `csharp`, `gatsby`, `react-native`, `spec-kit`) | the `scenario` in the repository's own `nen/repos.json` when it declares one; `bankai-machinery` for a Bankai process repository that declares none; else the framework its tree shows. It is not nen's lane `stack` (`claude-code-plugin` for this repository) |
| `owner` | a guild member | Fuegoleon for the Bankai process and library repositories (governance owner), Laxus for the products (code owner) |

- **No pins.** A repository's pins stay in its own `nen/` configuration and are read live, so a pin bump
  never edits this file.
- **G4 canon.** A change to `registry.json` needs the maintainer's G4 (zheref/hatsu#620, OQ-1). `fleet/` is in this
  repository's process set (`contracts/pr-composition.json` → `gateDerive`), so `nen gate derive`
  derives G4 for it.
- **Private rows are named by ruling.** A private repository may appear here only once a ruling names
  it: `zheref/akatsuki-ai` by HR-143, the other fourteen by HR-396
  ([`ROSTER.md`](../docs/ROSTER.md#hr-396); [`PUBLIC-REDACTION.md`](../docs/PUBLIC-REDACTION.md) § *Named private
  repositories*). Adding another needs its own ruling.
- **Not validated yet.** Validation of the roster, which fixes the `stack` vocabulary and compares
  `stack` against each repository's declared scenario, is zheref/hatsu#620's second child.
