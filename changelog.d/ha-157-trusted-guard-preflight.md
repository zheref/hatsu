### Preflight trusted pull request guards before opening a PR ([#157](https://github.com/zheref/hatsu/issues/157), 0.108.2)

Hanten and Mukai now run the base revision's `pull_request_target` guards against the proposed tree before PR creation. The guard set comes from the trusted workflows themselves. A mismatch names the two-step landing path in `docs/GATE-CONFIGURATION.md`.
