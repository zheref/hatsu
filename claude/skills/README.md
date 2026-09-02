# Hatsu skills

This directory is the plugin's skill surface (`plugin.json` → `"skills": "./claude/skills/"`). The summon
surface lives beside it at `claude/commands/` (`"commands": "./claude/commands/"`); both are listed together
under *Skills* by `claude plugin details`, which is why they are described together here.

## Declared deviation from "empty, reserved for #2"

[zheref/hatsu#1][1]'s scope says *"empty `skills/` surface reserved for #2."* **This surface is not empty,
deliberately**, and the deviation is declared rather than quietly taken.

It houses exactly **two roster-machinery residents** — neither of them one of the seventeen ported skills:

| Resident | Why it cannot wait for #2 |
|---|---|
| **`hatsu-warmup/SKILL.md`** | It is the D10 dependency contract *executing*. #1's own acceptance evidence is written in terms of it — *"the **skill** halts printing the exact command"* — so the contract cannot be wired at warm-up without it. It must also work **before** any other Nen-owned work, including every skill #2 brings. |
| **`../commands/kurapika.md`** | The `/kurapika` summon surface both manifests advertise. An agent definition alone creates no invocable command, so without this the manifests describe a surface that does not exist. Mirrors bankai's proven `claude/commands/ichigo.md`. |

**The reservation still holds for what it was about**: the seventeen ported skills. Nothing here is one of
them, and nothing here front-runs the verb-surface work that is #2's reason to exist.

[1]: https://github.com/zheref/hatsu/issues/1

## What is here now

- **`hatsu-warmup/`** — the D10 Nen dependency contract, executed. Probes `nen --version` against the range
  declared in `nen.contract.json` (at `0.x`, `minimum: "0.1"` means `>=0.1.0 <0.2.0`); when nen is **absent**
  it runs nen's own checksum-verified bootstrap directly, and when nen is **present but out of range** it
  re-pins through `nen bootstrap --script`. It halts with the exact command **only** if that bootstrap fails.

## What is reserved

The **seventeen ported skills** land at [zheref/hatsu#2][2], under their existing names — `backlog-state`,
`backlog-board`, `backlog-loop`, `backlog-synthesis`, `build`, `drive`, `file`, `futon`, `getsuga`,
`izanagi`, `izanami`, `jujisho`, `pr-state`, `senkei`, `tensho`, plus the two resolvers. Only their
mechanics change: improvised shell becomes deterministic Nen verbs. **Do not port one here** — #2 needs the
full verb surface, which is why the split exists.

Each skill is a directory holding a `SKILL.md` with `name` and `description` frontmatter.

[2]: https://github.com/zheref/hatsu/issues/2
