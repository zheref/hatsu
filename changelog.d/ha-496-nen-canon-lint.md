### Changed

- Run the pinned `nen canon lint` in the canon prose workflow and trusted preflight (zheref/hatsu#496). The workflow verifies both the bootstrap script and binary against the trusted revision. The old TypeScript lint and its fixture lane retire. The morning desk retains its Git-based baseline history report. Update installed morning desk prompts and allowed commands to use `node scripts/prose_lint_history.mts --root . --history 10`.
