# Native client readiness gates

WinInspect `v0.4.2` is the MVP package used to prove the corrected public execution architecture.

A client is ready for private promotion consideration only after a public hosted-Windows run proves the exact immutable release subject through that client's normal lifecycle.

## Required evidence

### WinGet

- exact portable ZIP URL and SHA-256;
- manifest validation;
- install through local manifest;
- expected command aliases created;
- repeat install succeeds;
- uninstall by the exact local manifest with purge;
- aliases/install state removed.

### Scoop

- exact portable ZIP URL and SHA-256;
- bucket constructed as a Git repository using `bucket/<id>.json`;
- bucket added normally;
- install through the bucket;
- expected archive-relative binaries present;
- repeat install succeeds without corrupting state;
- uninstall succeeds and Scoop app/shim state is removed.

### Chocolatey

- deterministic `.nuspec` and scripts produce a local `.nupkg`;
- the package references the exact immutable NSIS URL and SHA-256;
- install from an isolated local feed;
- expected user-scope WinInspect state appears with no machine-scope registration;
- repeat/force install succeeds;
- Chocolatey uninstall invokes deterministic product cleanup;
- application and Chocolatey package state are removed.

These are distribution/client mechanics. Passing them is necessary evidence for private promotion, but does not itself grant promotion approval.
