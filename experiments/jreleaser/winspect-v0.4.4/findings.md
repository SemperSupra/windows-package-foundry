# JReleaser RDTE findings — WinInspect v0.4.4

Status: **experiment complete enough for an architectural decision; no production adoption or external publication authorized.**

## Question

Can JReleaser act as a generic projection/compiler backend beneath Foundry, eliminating a substantial amount of venue-format generation while Foundry retains policy, private validation, promotion authority, and evidence?

## Execution record

The experiment used:

- JReleaser `1.25.0`;
- JReleaser release ZIP SHA-256 `7c086a384e509ae30ad12ce2f10946601c0798e746d06a5538afc267e398644b`;
- WinInspect `v0.4.4` source SHA `b2d07ae3ff1df53a62c27ec3fa27f1452ff5926a`;
- portable ZIP SHA-256 `6ac0a65f774ffe69672f1c459254931ebfddb1e52c9fbec14b5db1348ccaad04`;
- NSIS installer SHA-256 `601d5f54083ea8922328b8b35d9094b8fb2eb8e8d243dd0883de90fb9919acba`.

Final successful hosted run: `33237792157` at public Foundry commit `4263ed0d157632365f897b0ca3f4f668e94626dc`.

Public security validation for the same commit also passed.

The public runner had `contents: read` only. No real GitHub/registry/store credential was supplied. JReleaser requires a nonblank GitHub releaser token even when release/tag/upload are disabled, so a deliberately invalid non-secret sentinel string was supplied solely to satisfy configuration validation. The executable wrapper permitted only `config`, `prepare`, and `package`; `package` additionally used `--dry-run`.

## Fixture correction

The original experiment selected historical WinInspect `v0.4.2` because private Foundry had previously re-intaken that release. The first run failed closed because the release is no longer exposed by the current public GitHub release endpoint and its asset URLs returned 404.

The experiment therefore switched to current public `v0.4.4` as a mechanical fixture. This does not assert private promotion approval for v0.4.4.

Lesson: **a historical approval record is not sufficient as a future projection input; the release contract must also bind to a durable currently-resolvable hosted artifact identity or an explicitly retained immutable archive.**

## Results

### 1. One configuration can drive multiple Windows projections — PASS

A single JReleaser model produced:

- Scoop JSON;
- a three-file WinGet manifest set;
- Chocolatey NuSpec + install script;
- Chocolatey source that `choco pack` converted into a `.nupkg`.

This materially supports the thesis that Foundry should delegate boring venue-format generation rather than maintain bespoke emitters for every package ecosystem.

### 2. Immutable artifact URLs and hashes — PASS

The generated package metadata preserved the exact public GitHub Release URLs and SHA-256 values supplied by the experiment fixture.

### 3. Local generation without publication — PASS

JReleaser cleanly generated package material using `config` / `prepare` / `package` without invoking an external publication operation. All packager repository outputs were disabled and `skipPublishing` was enabled.

This is compatible with Foundry's intended boundary: generation can happen before any promotion authority is granted.

### 4. Native structural validation — PASS

On a Windows GitHub runner:

- Scoop JSON parsed successfully;
- Microsoft `winget validate` accepted the generated manifest set after removing duplicated configuration-level tags;
- Chocolatey parsed the NuSpec and `choco pack` successfully built `wininspect.0.4.4.nupkg`;
- package SHA-256: `b96877218eea9ea4687272ba82202572e5baf91f030d6137a37da18e47d28c13`.

This demonstrates that JReleaser output is not merely syntactically plausible to JReleaser itself; key outputs are consumable by the venue-native Windows tools.

### 5. Same-run deterministic generation — PASS WITH CAVEAT

Two consecutive `--reproducible` generations in the same hosted job produced the same package-file hashes.

However, the generated WinGet installer manifest contains `ReleaseDate: 2026-08-29`, the generation date, while the immutable upstream release was published on `2026-08-23`. Therefore cross-day byte stability is **not proven** by the same-run comparison. A production adapter should bind release date to immutable release metadata or override the template.

### 6. Drop-in equivalence with current Foundry semantics — FAIL / EXPECTED CUSTOMIZATION

The default output is structurally valid but is not a drop-in replacement for the current Foundry-generated client contracts.

#### Chocolatey

JReleaser generated:

`silentArgs = "/quiet"`

The currently validated WinInspect Foundry lifecycle uses:

`/S /MANAGED-BY=chocolatey`

The ownership marker is semantically important for managed uninstall/cleanup behavior. JReleaser supports custom package templates and extra properties; the likely production design is therefore a small Foundry-owned Chocolatey template layered on the generic JReleaser backend.

#### Scoop

The generated manifest points at the correct portable ZIP and path but does not emit the explicit command shim set expected by current Foundry client semantics. Its default autoupdate/hash assumptions also do not match the Foundry trust-bundle model exactly.

A Foundry-owned template or explicit Scoop configuration remains necessary.

#### WinGet

The generated manifest passed `winget validate`, but it currently:

- exposes only the primary `wininspect` command;
- reports architecture as `neutral` despite an x86-64 fixture declaration;
- uses manifest schema `1.9.0` rather than Foundry's current `1.10.0` compatibility floor/default;
- derives release date from generation time.

These are adapter-policy/template issues rather than reasons to reject JReleaser as a backend.

## Friction discovered in integration

JReleaser 1.25.0 also imposed several integration requirements worth encoding in any future wrapper:

1. A config stored below the repository root required `--git-root-search`.
2. Strict validation required project copyright and distribution tags.
3. A GitHub release provider required a nonblank token even with tag/release/upload disabled; the RDTE harness used a non-secret invalid sentinel rather than granting credentials.
4. Defining the same tags at both project and WinGet levels caused a manifest that JReleaser generated but Microsoft's validator rejected for duplicate elements. Native venue validation therefore remains mandatory.
5. JReleaser's `--reproducible` mode improves stability but does not by itself guarantee that every generated semantic field is bound to immutable upstream release facts.

## Decision

**Adopt JReleaser as a promising supported generic projection backend, not as Foundry authority and not as the universal publishing engine.**

The experiment is positive because JReleaser eliminated most of the mechanical work needed to emit three Windows package formats from one description and produced artifacts accepted by native tools with modest configuration correction.

The experiment also confirms the red-team boundary: Foundry must retain the semantic model and venue-specific policy that matter to lifecycle correctness. JReleaser should be treated like a compiler with small Foundry-owned templates/adapters, while venue-native tools remain the validators and eventual publishers.

Recommended shape:

```text
private Foundry approved/qualified release state
        |
        v
sanitized normalized release description
        |
        v
JReleaser generic projection backend
        |
        +--> Foundry-owned thin templates where semantics matter
        |
        v
venue-native validation
        |
        v
non-authoritative public projection / RDTE artifact
        |
        v
separate promotion authority
        |
        v
venue-native publisher (future)
```

For future macOS/Linux work, repeat the same model rather than extending Windows-specific booleans: JReleaser may generate Homebrew/AppImage/Flatpak/Snap/RPM-related material where useful, but App Store Connect, Apple notarization, Snapcraft, OBS/Flathub, and other venue-owned systems should retain their native consequential operations.

## Production-adoption gate

Before replacing an existing Foundry generator with JReleaser in production:

- add thin templates that exactly reproduce the validated client lifecycle semantics;
- bind generated dates and other release facts to immutable source/release metadata;
- compare JReleaser output with the current Foundry generator over at least one full install/upgrade/uninstall lifecycle;
- use native venue validators in CI;
- preserve fail-closed private promotion authority;
- do not expose publisher credentials to generic public build jobs.

The generated baseline and native-validation artifacts are preserved under `generated/` for subsequent local consumption and adapter work.
