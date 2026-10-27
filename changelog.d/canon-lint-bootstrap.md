### Changed

- Prepare the first landing of #496: the trusted workflow validator admits the current Node canon lint and the exact Nen form with trusted pin, bootstrap and digest steps. Both installed forms pass the full trusted self-test entrypoint. The new Nen form checks the downloaded bootstrap script against the trusted script digest before execution, then checks the binary independently. The live workflow stays on Node until this validator merges; the workflow flip and old guard retirement remain step two.
