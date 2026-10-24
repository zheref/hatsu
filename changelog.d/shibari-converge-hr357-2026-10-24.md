### Fixed

- **`hatsu:shibari` § 4 hands a closing-free stacked sub-PR to `en` (HR-357).** The `pr converge` bullet said never to hand to `en` on exit `1`, while `hatsu:en` § 4 reads converge's exit `1` with `closingSource` `none-on-non-default-base` (a non-default-base PR that closes no issue) as not applicable under HR-357, so a stacked sub-PR closing nothing stalled in shibari. The bullet now carries that one exception, cites HR-11 and HR-357, and points both shibari guards at `en` §§ 4–5 and `sharingan` § 4 for their re-runs. Installed copies get the change by updating to `0.141.1`.
