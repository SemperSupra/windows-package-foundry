# Client interface red-team findings

Status: accepted implementation constraints

This record captures the adversarial review of the public Foundry client UX/DX design. It narrows the implementation rather than expanding it.

## Decisions

1. **Do not make the web site the Foundry authority.** The static site is a generated discoverability, bootstrap, and status surface. The immutable product release plus projected Foundry state remains the public identity/evidence chain.
2. **Prefer static generation over a framework SPA.** Generate useful HTML and versioned JSON from the same public package model. JavaScript may improve search/copy/filter UX, but critical package state and commands must remain visible without JavaScript.
3. **Do not add package-server infrastructure merely for symmetry.** Scoop is natively a Git/static bucket. WinGet local manifests and Chocolatey local-folder feeds are the MVP client paths. Remote WinGet/Chocolatey services are deferred until measured friction justifies their compatibility burden.
4. **Reject the static-NuGet-v3 shortcut as an architectural dependency.** NuGet/Chocolatey search semantics are request-dependent; a static site should not pretend to be a protocol server by returning precomputed or over-broad search results.
5. **Use explicit source selection where a remote source is eventually added.** Optimize commands for provenance clarity and collision resistance, not minimum keystrokes.
6. **One authority does not mean one lowest-common-denominator schema.** A public package model contains common identity/release/trust/lifecycle facts plus typed client-specific sections for WinGet, Scoop, and Chocolatey.
7. **Generate atomically.** HTML, JSON, and client projections for a package release must be generated from the same model/revision and validated together. Never update package-manager surfaces independently.
8. **Fail closed on lifecycle/promotion state.** Installable client projections may not be generated from a package whose private-approved public projection does not explicitly report lifecycle and promotion approval.
9. **Adapters, if later justified, are translators only.** They consume sanitized public projection data, hold no authoritative package state, and have no credential or network path into private Foundry state.
10. **Prefer a compatible manifest floor over unnecessary client upgrades.** The WinGet MVP uses the frozen singleton manifest schema `1.10.0`; it contains every field the Foundry currently needs and is accepted by a broader installed-client range than newer schema revisions. Raise the floor only when a required field or behavior justifies doing so.
11. **Select the best approved artifact per client instead of forcing one installer through every package manager.** Common identity, version, provenance, and lifecycle state stay singular; client sections may select different already-approved release artifacts when the package manager has a better native representation. For WinInspect v0.4.2, Scoop and WinGet use the existing portable ZIP, while direct install and Chocolatey use the NSIS installer.
12. **Do not encode unsupported package-manager metadata for symmetry.** WinGet portable installers do not accept `Scope`; the portable manifest omits it rather than pretending the archive has NSIS-style scope metadata.

## Evidence-driven WinInspect MVP choice

The first WinInspect lifecycle attempts established three distinct facts that must not be conflated:

- the exact `v0.4.2` release installer and portable ZIP both have immutable release hashes and approved public provenance;
- direct NSIS lifecycle testing on a clean hosted Windows runner proves package -> silent install -> repeat silent install -> silent uninstall -> converged cleanup succeeds;
- NSIS consumed through WinGet can stall after WinGet reports `Starting package install...`, even though the same NSIS package works directly. That integration path remains diagnostic rather than the supported MVP WinGet surface.

The existing `WinInspectPortable-v0.4.2.zip` contains the three release executables under `App/WinInspect/` before any PortableApps launcher is added. WinGet therefore models the archive natively as `InstallerType: zip` with `NestedInstallerType: portable` and three command aliases (`wininspect`, `wininspectd`, `wininspect-gui`). Scoop consumes the same portable archive. This reuses an already-attested release artifact and avoids manufacturing a new release solely to work around a package-manager/NSIS integration seam.

The hosted-Windows proof must still pass the complete WinGet portable lifecycle, including exact archive hash verification, manifest validation, install, alias creation, repeat install, uninstall, and alias cleanup, before private Foundry may approve promotion.

## MVP target

```text
private Foundry policy/validation
        |
        | sanitized approved projection
        v
public package model
        |
        +-- generated static HTML
        +-- generated versioned JSON
        +-- generated Scoop bucket ---------> approved portable artifact
        +-- generated WinGet local manifest -> approved portable artifact
        `-- generated Chocolatey source -----> approved NSIS artifact
```

Product release workflows should prove their own packaged artifacts before publication. Foundry then proves the package-manager-specific consumption path against the immutable released artifact. The two gates are complementary: product lifecycle testing catches package defects before release; Foundry lifecycle testing catches client-integration defects before promotion.

## Deferred

- WinGet REST source adapter;
- Chocolatey/NuGet HTTP feed adapter;
- database-backed catalog;
- JavaScript application framework;
- NSIS-through-WinGet as a required MVP path while the portable path is cleaner and independently verifiable;
- external community-registry publication as a release dependency.

Reconsider a deferred item only when actual use demonstrates enough friction or scale to justify its operational and compatibility cost.
