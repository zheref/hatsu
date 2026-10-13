### Changed

- **Step one of the prose-diet guard in CI: `prose-size-check.yml` is registered in the workflow-policy validator and ships inert at `templates/`** ([#135](https://github.com/zheref/hatsu/issues/135)). The validator judges every pull request from the base, so the workflow's job, trigger, draft-skip guard, check creation and frozen guard step are learned one PR before the file moves under `.github/workflows/` (#80's order). Plugin bumped to 0.105.1 (`templates/` ships); mirrors restamped.
