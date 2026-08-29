# JReleaser generalization and venue-routing findings

Status: **RDTE / non-authoritative / not promoted**

Authority: private Foundry #45/#46; public execution issues #20/#21.

## Result

**PASS WITH QUALIFICATION.**

The two experiments strengthen the original WinInspect feasibility result and expose one necessary production-design correction: Foundry must model **per-venue eligibility/capability before execution**, not merely choose a projection backend from artifact class.

## Experiment A — AgentKVM2USB

AgentKVM2USB `v0.2.0` is materially different from WinInspect: it is a deterministic flat-root portable ZIP, depends on host Python, exposes `Run-AgentKVM2USB.cmd`, carries an explicit `Install-Dependencies.cmd` bootstrap, and owns only its extracted tree.

Observed results:

- exact release ZIP SHA-256 verification: passed;
- JReleaser 1.25.0 strict config/prepare/package: passed after adding required declarative license URL metadata;
- repeated same-run JReleaser package output: byte-stable;
- product-specific procedural generator code: **0 lines**;
- JReleaser default flat-root ZIP assumptions were wrong for Scoop/WinGet, so a reusable `portable-zip` semantic normalizer was added, driven only by normalized release facts;
- Scoop command mapping after generic normalization: passed;
- Chocolatey source generation and native `choco pack`: passed;
- bounded portable lifecycle on a clean hosted Windows runner: exact hash, command/bootstrap presence, repeat materialization, and extracted-tree uninstall all passed;
- dependency bootstrap execution was intentionally not run because it performs network-heavy Python dependency installation and leads into hardware-dependent behavior;
- physical KVM/UVC/HID behavior remains out of scope;
- true prior-version upgrade remains unproven; only repeat/same-version materialization was exercised;
- cross-day reproducibility remains unproven even though same-run stability passed.

### WinGet capability finding

JReleaser first inferred an invalid single-root/bin path for the flat-root ZIP. After generic path normalization, Microsoft's native `winget validate` still rejected the actual nested entry point `Run-AgentKVM2USB.cmd` with:

`The file type of the referenced file is not allowed.`

This was reproduced in workflow runs `33240256320` and `33240357659`.

The correct conclusion is **not** to add a product-specific workaround. The current AgentKVM2USB artifact is **not eligible for the local WinGet ZIP/portable target as currently declared**. A later product packaging change could add a supported launcher/artifact and cause capability evaluation to change.

The experimental planner therefore now emits per-venue `eligible` state and reason code `venue.winget.nested-portable-cmd-rejected-by-native-validator` for this topology.

This also identifies a follow-up audit item: the existing AgentKVM2USB `.package-foundry/package.json` declares `wingetLocal.enabled=true`, which is more optimistic than the native validator evidence. This RDTE does not mutate production product/package authority; that correction should be made through normal Foundry governance.

## Experiment B — OXCE Mod Studio VSIX negative control

The same normalized release planner classified the experimental VSIX as venue-native and emitted:

- artifact class: `vsix`;
- generic projection backend: `null`;
- adapter: `venue-native`;
- reason codes: `artifact.vsix`, `projection.generic-backend-not-required`, `venue.native-packaging-authoritative`;
- publication authorization: false.

The exact VSIX SHA-256 and extension manifest/identity/version/VS Code engine constraint were validated. The hosted Windows image did not expose `code.cmd`, so CLI install and activation were honestly recorded as unavailable/not-run rather than simulated. Existing product-side headless activation evidence remains separate from this Foundry routing experiment.

No VSIX-specific procedural code was added to Foundry core, and JReleaser was not invoked for the VSIX.

## Architectural decision

The evidence now supports this shape:

`normalized release -> artifact classification -> per-venue capability/eligibility -> projection backend (when useful) -> generic semantic adapter -> native venue validation -> separate promotion/publication gate`

JReleaser remains a good generic projection/compiler backend. It should **not** be the universal router or authority.

Important derived rules:

1. Product-specific **data** is expected; product-specific procedural generators are a failure smell.
2. Reusable semantic adapters are legitimate when a backend makes generic layout assumptions not guaranteed by Foundry's normalized model.
3. Venue eligibility must be checked before invoking publication/validation machinery that cannot support the artifact topology.
4. Venue-native artifact classes such as VSIX should bypass JReleaser when it adds no value.
5. A negative native-validator result is durable capability evidence, not something to be patched around to make CI green.
6. Cross-platform expansion should preserve this separation for macOS/Linux rather than encode every venue schema into Foundry core.

## Production-readiness gaps still open

This tranche demonstrates architectural feasibility/generalization, not production migration readiness. Before production adoption, Foundry still needs a governed normalized release schema, adapter interface, explicit capability registry/reason codes, cross-day reproducibility checks, and broader lifecycle/upgrade coverage on products whose runtime topology permits it.

No external package/store/Marketplace publication occurred and no promotion/eligibility authority was changed by these experiments.
