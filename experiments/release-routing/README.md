# Release routing RDTE tranche

Status: **RDTE / non-authoritative / not promoted**.

Authority: private Foundry issues `#45` and `#46`; public execution issues `#20` and `#21`.

This tranche follows the WinInspect JReleaser feasibility experiment. It does not re-test whether JReleaser can generate package-manager metadata. It tests two stronger architectural hypotheses:

1. **Generalization:** AgentKVM2USB must flow through the same normalized release model and generic JReleaser backend with zero product-specific procedural generator code. Its portable archive has host-Python, dependency-bootstrap, command-alias, and extracted-tree ownership semantics that differ materially from WinInspect.
2. **Negative-control routing:** OXCE Mod Studio's VSIX must be classified as venue-native. The planner must bypass JReleaser and route to VS Code extension semantics without importing VSIX-specific schemas or procedures into Foundry core.

The deterministic planner in `planner.py` intentionally contains only artifact/venue capability routing. Product-specific facts live in normalized JSON fixtures. All publication authorization is false.

## Decision gate

The tranche supports the generalized architecture only if:

- AgentKVM2USB selects JReleaser and produces Scoop/WinGet/Chocolatey projections without product-specific procedural generator code;
- native structural/package checks and bounded portable lifecycle checks succeed or failures reveal explicit reusable semantic gaps;
- OXCE VSIX deterministically selects the venue-native route with reason codes and no generic projection backend;
- no external registry/store/Marketplace publication occurs;
- no private repository data or credentials enter public execution.

Cross-day reproducibility cannot be proven by a single workflow execution. This tranche records same-run stability and explicitly leaves cross-day status outstanding unless a later independent run compares preserved hashes.
