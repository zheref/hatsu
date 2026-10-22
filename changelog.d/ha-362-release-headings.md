### Fixed

- **#362 Release notes from collated changelogs** ([#362](https://github.com/zheref/hatsu/issues/362)). The generated release publisher reads the changelog's own heading level through a TypeScript helper, accepts Nen's `###` sections and existing `##` changelogs, and refuses absent or mixed-level tag boundaries. Process consumers render the helper with Tenkai and need Node 22.18+.
