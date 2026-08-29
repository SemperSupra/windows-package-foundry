# Generated JReleaser RDTE outputs

**Status: RDTE / non-authoritative / not promoted.**

These files are preserved so humans, automation, and later Foundry work can consume and inspect the actual output of the JReleaser experiment without depending on an expiring GitHub Actions artifact.

They were generated from the public WinInspect `v0.4.4` release by JReleaser `1.25.0`, then subjected to structural/native-tool validation in GitHub Actions run `33237792157`.

Validation performed:

- JReleaser `config`, `prepare`, and `package` only;
- repeated JReleaser generation in the same run with `--reproducible`: byte-stable for the compared generated package files;
- Scoop manifest JSON parse: passed;
- Microsoft `winget validate`: passed;
- Chocolatey NuSpec XML parse: passed;
- `choco pack`: passed, producing `wininspect.0.4.4.nupkg`.

Validation **not** performed:

- install/upgrade/uninstall lifecycle through these generated packages;
- external package-manager publication;
- Microsoft Store/App Store/other store submission;
- any change to private Foundry eligibility or promotion state.

Known semantic gaps remain. The default Chocolatey template uses `/quiet`, while the existing validated Foundry WinInspect ownership contract uses `/S /MANAGED-BY=chocolatey`. The default Scoop manifest does not expose the explicit command shim set expected by current Foundry client semantics. The generated WinGet manifest exposes only the primary `wininspect` command, reports architecture as `neutral`, and derives `ReleaseDate` from generation time rather than the immutable upstream release date.

Accordingly, these are useful **backend/compiler outputs and fixtures**, not production-ready promoted package records. See `../findings.md` for the experiment conclusion.
