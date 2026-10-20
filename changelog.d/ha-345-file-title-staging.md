### Fixed

- **`hatsu:file` § 4 no longer stages the title through a quoted heredoc.** It told the filer to write `title.txt` with `cat > title.txt <<'EOF'`, the construction `docs/PROCESS.md` § *Escaping the maintainer's words* forbids, since a quoted heredoc's delimiter is in-band. § 4 now says to write every draft (title, body, comment) with the surface's own file-writing tool and points at that PROCESS section rather than restating it (zheref/hatsu#345). The `--title-file` / `--line-file` machinery is unchanged. Plugin bumped to 0.128.1.
