### Fixed

- Codex idle startup now reaches supported write recovery before treating a sandbox failure as a terminal denial, including failures in Git metadata and run-manifest creation. A failed manifest is reported as an unpersisted startup hold. Closes #349.
