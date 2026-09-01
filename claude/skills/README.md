# Hatsu skills

This directory is the plugin's skill surface (`plugin.json` → `"skills": "./claude/skills/"`).

## What is here now

- **`hatsu-warmup/`** — the D10 Nen dependency contract, executed. Probes `nen --version` against the
  minimum declared in `nen.contract.json`; when nen is absent or below minimum it runs nen's own
  checksum-verified bootstrap at the pinned ref; it halts with the exact command **only** if that
  bootstrap fails. It is the one skill that must work before any other Nen-owned work can start, which
  is why it ships in the bootstrap issue rather than with the ported set.

## What is reserved

The **seventeen ported skills** land at [zheref/hatsu#2][2], under their existing names — `backlog-state`,
`backlog-board`, `backlog-loop`, `backlog-synthesis`, `build`, `drive`, `file`, `futon`, `getsuga`,
`izanagi`, `izanami`, `jujisho`, `pr-state`, `senkei`, `tensho`, plus the two resolvers. Only their
mechanics change: improvised shell becomes deterministic Nen verbs. **Do not port one here** — #2 needs
the full verb surface, which is why the split exists.

Each skill is a directory holding a `SKILL.md` with `name` and `description` frontmatter.

[2]: https://github.com/zheref/hatsu/issues/2
