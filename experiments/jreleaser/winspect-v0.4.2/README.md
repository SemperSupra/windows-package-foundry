# JReleaser RDTE — WinInspect v0.4.2

Status: **RDTE / non-authoritative / not promoted**

Governing issues:

- public execution: `SemperSupra/windows-package-foundry#17`
- private authority/findings: `SemperSupra/windows-package-foundry-private#44`

## Purpose

Evaluate JReleaser as a generic package-projection backend beneath Foundry. The experiment consumes immutable, already-public WinInspect release facts and asks JReleaser to generate local Scoop, WinGet, and Chocolatey package material without publishing anything externally.

JReleaser is not package-policy authority. These files do not grant or imply Foundry promotion approval.

## Fixed fixture

- repository: `SemperSupra/WinInspect`
- tag: `v0.4.2`
- source SHA: `0e3c3d588ca320c287589cd469e50c88370584a8`
- portable ZIP: `WinInspectPortable-v0.4.2.zip`
- portable SHA-256: `34c6019b1ac59f284f5d88e6864e88de71043e36e5c61c0f78d052cd14790e0a`
- installer EXE: `WinInspect-Installer-v0.4.2.exe`
- installer SHA-256: `77d05af906737bfd259c65901636e9e8cd0ea659d0f48c069189d7492e606809`

JReleaser is pinned to `1.25.0`; its release ZIP SHA-256 is `7c086a384e509ae30ad12ce2f10946601c0798e746d06a5538afc267e398644b`.

## Safety boundary

The harness is intentionally limited to JReleaser `config`, `prepare`, and `package`. It does not invoke `publish`, `release`, `full-release`, `upload`, `deploy`, or `announce`. All configured packagers set `skipPublishing: true` and their backing repositories are disabled.

No registry/store credentials are used. No private repository is read. No generated file is written into the live promoted `distribution/` namespace.

## Expected experiment products

The workflow generates two logical distributions from the same release description:

1. `wininspect-portable` — immutable portable ZIP projected to Scoop and WinGet.
2. `wininspect-installer` — immutable NSIS installer projected to Chocolatey.

The generated JReleaser trees, logs, and a SHA-256 inventory are retained as a workflow artifact. After the experiment is stable, the useful generated package files are copied into this experiment directory so consumers can inspect/use them locally from the public Foundry without confusing them with promoted state.

## Evaluation questions

- Can one normalized release description drive all three Windows projections?
- Does JReleaser preserve immutable release URLs and hashes?
- How much custom templating is required to preserve current Foundry semantics?
- Are repeated `--reproducible` runs stable?
- Can package material be generated without any publication step or credentials?
- Which venue-specific operations should remain delegated to native tools instead?

No production adoption follows automatically from a successful experiment.