# Native client readiness gates

WinInspect is the MVP package used to prove the corrected public execution architecture. Client lifecycle proof is **release-candidate driven** rather than bound forever to one historical repository/tag.

A client is ready for private promotion consideration only after a public hosted-Windows run proves an exact immutable release subject through that client's normal lifecycle. The workflow accepts a public release repository, immutable tag/version, and exact artifact hashes at dispatch time; pull requests exercise only the harness/contract itself.

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
- generated package metadata points to the candidate release/version rather than historical `v0.4.2`;
- Chocolatey invokes the NSIS installer with the explicit ownership handoff `/MANAGED-BY=chocolatey` in addition to `/S`;
- install from an isolated local feed succeeds through that authorized package-manager path;
- expected user-scope WinInspect state appears with no machine-scope registration;
- while Chocolatey owns the installed package, a direct bare silent NSIS `/S` invocation is rejected with a nonzero exit and leaves the managed install intact;
- repeat/force Chocolatey install succeeds through the explicit ownership handoff;
- Chocolatey uninstall invokes deterministic product cleanup;
- application and Chocolatey package state are removed.

The ownership handoff is deliberate: **silent mode is not authorization**. A package manager that owns the installation must identify itself explicitly; an ordinary unattended installer must not silently cross another client's ownership boundary.

## Candidate invocation

After the public WinInspect deployment plane creates an immutable release, dispatch `WinInspect native client readiness` with:

- `release_repo` — normally `SemperSupra/WinInspect`;
- `release_tag` — `vX.Y.Z`;
- `version` — `X.Y.Z`;
- `portable_sha256` — exact release ZIP hash;
- `installer_sha256` — exact NSIS release hash.

The workflow derives standard release URLs from those immutable inputs and preserves client-specific evidence artifacts. Historical private-repository release URLs are not part of the durable client contract.

These are distribution/client mechanics. Passing them is necessary evidence for private promotion, but does not itself grant promotion approval.
