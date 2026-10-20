### Changed

- Run the redaction-guard fixture as a frozen `Redaction guard fixture` step of `surface-mirror-check.yml`, on the trusted checkout with no secret, no private list and no token, so a guard regression goes red in CI; the workflow-policy validator now requires the step, completing the two-step landing. (HA-IS-#337)
