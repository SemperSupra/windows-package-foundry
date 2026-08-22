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
        +-- generated Scoop bucket
        +-- generated WinGet local manifest
        `-- generated Chocolatey package source
```

For WinInspect, first prove the exact released installer through a clean hosted-Windows WinGet local-manifest install/uninstall lifecycle. Only after that evidence is accepted by the private Foundry may the real installable public projection be published.

## Deferred

- WinGet REST source adapter;
- Chocolatey/NuGet HTTP feed adapter;
- database-backed catalog;
- JavaScript application framework;
- external community-registry publication as a release dependency.

Reconsider a deferred item only when actual use demonstrates enough friction or scale to justify its operational and compatibility cost.
