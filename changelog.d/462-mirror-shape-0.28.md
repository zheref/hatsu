### Changed

- The generated mirrors take nen 0.28.0's shape (regenerated at 0.144.0 with the released pin): every Antigravity persona's `tools:` is a list of Antigravity names (`view_file`, `run_command`; the other Claude tool names have no documented Antigravity name and are dropped, zheref/nen#505 OQ-1), so personas that agy 1.4.3 silently skipped under the old comma string now load (measured on the mirrors of 0.143.0 and 0.144.0, 2026-10-25); and the Cursor mirrors of the seven read-only personas (bisky, buhara, illumi, leorio, lippo, satotz, shizuku) carry `readonly: true`. Part of #449.
