### Changed

- **Step one of the CI nen-digest check: the workflow-policy validator learns the digest step that sits beside each bootstrap** ([#230](https://github.com/zheref/hatsu/issues/230)). The validator judges every pull request from the base, so the step is registered — and its frozen body proven under bash against a scratch binary and contract, nine cases per body — one PR before the live workflows take it. No workflow, contract or shipped surface changes in this step.
