### Changed

- **#234 trusted direct-matrix CI policy** ([#234](https://github.com/zheref/hatsu/issues/234)). The workflow validator now admits the exact TypeScript-backed matrix drift step, while preserving the current no-step workflow during the staged landing. The adapter fences untrusted renderer output and reports its verdict; a focused fixture proves hostile output stays fenced. Plugin bumped to 0.114.6 and mirrors restamped. A follow-up PR installs the CI step.
