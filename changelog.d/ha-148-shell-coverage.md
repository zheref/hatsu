### Changed

- Add exact-source capture and extraction to eight remaining focused shell lanes, including both publish integrity targets. Move report-time assertions into a dedicated fixture while preserving and verifying its --self-test forwarding path. Preserve strict absent-ignore redaction behavior. Live tree capture remains held for an explicit maintainer naming/policy decision under #149, and trusted preflight stays unsupported for its Ruby implementation and archived historical guard copies. Delivers part of #148; the issue remains open and the 80/85/90 ladder is unchanged.

- Wire the report-time companion into the trusted CI runner, refusing a missing companion and propagating fixture failures. Automatic workflow selection begins after the updated runner is adopted by the PR base.
