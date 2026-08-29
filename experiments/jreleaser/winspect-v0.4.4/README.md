# JReleaser RDTE — WinInspect v0.4.4

Status: **RDTE / non-authoritative / not promoted**

Governing issues:

- public execution: `SemperSupra/windows-package-foundry#17`
- private authority/findings: `SemperSupra/windows-package-foundry-private#44`

## Purpose

Evaluate JReleaser as a generic package-projection backend beneath Foundry. The experiment consumes immutable, public WinInspect release facts and asks JReleaser to generate local Scoop, WinGet, and Chocolatey package material without publishing anything externally.

JReleaser is not package-policy authority. These files do not grant or imply Foundry promotion approval.

## Fixture correction

The experiment initially selected historical `v0.4.2` because its release provenance had been previously reviewed. The first hosted run proved that the release is no longer exposed through the current public `SemperSupra/WinInspect` release endpoint; the asset acquisition failed with HTTP 404 before package generation.

The RDTE fixture was therefore changed to current public `v0.4.4`. This is a mechanical test input only, not a promotion decision.

## Fixed public fixture

- repository: `SemperSupra/WinInspect`
- tag: `v0.4.4`
- source SHA: `b2d07ae3ff1df53a62c27ec3fa27f1452ff5926a`
- portable ZIP: `WinInspectPortable-v0.4.4.zip`
- portable SHA-256: `6ac0a65f774ffe69672f1c459254931ebfddb1e52c9fbec14b5db1348ccaad04`
- installer EXE: `WinInspect-Installer-v0.4.4.exe`
- installer SHA-256: `601d5f54083ea8922328b8b35d9094b8fb2eb8e8d243dd0883de90fb9919acba`

The public v0.4.4 release also contains Foundry build-context, checksums, SBOM, and provenance-attestation artifacts. The experiment does not interpret those as a private promotion verdict.

JReleaser is pinned to `1.25.0`; its release ZIP SHA-256 is `7c086a384e509ae30ad12ce2f10946601c0798e746d06a5538afc267e398644b`.

## Safety boundary

The harness is intentionally limited to JReleaser `config`, `prepare`, and `package`. It does not invoke any publication, release creation, upload, deployment, or announcement operation. All configured packagers set `skipPublishing: true` and their backing repositories are disabled. `package` additionally runs with JReleaser `--dry-run`.

No registry/store credentials are used. No private repository is read. No generated file is written into the live promoted `distribution/` namespace.

## Expected experiment products

The workflow generates two logical distributions from the same release description:

1. `wininspect-portable` — immutable portable ZIP projected to Scoop and WinGet.
2. `wininspect-installer` — immutable NSIS installer projected to Chocolatey.

The generated JReleaser trees, logs, and a SHA-256 inventory are retained as a workflow artifact. Stable useful generated package files are then preserved under this RDTE path so they may be inspected or consumed locally without being confused with promoted state.

## Evaluation questions

- Can one normalized release description drive all three Windows projections?
- Does JReleaser preserve immutable release URLs and hashes?
- How much custom templating is required to preserve current Foundry semantics?
- Are repeated `--reproducible` runs stable?
- Can package material be generated without any publication step or credentials?
- Which venue-specific operations should remain delegated to native tools instead?

No production adoption follows automatically from a successful experiment.