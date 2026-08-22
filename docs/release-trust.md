# Public release trust envelope

Windows Package Foundry provides a reusable public release-trust envelope for products that are already safe to build from public source.

The trust envelope is intentionally **not** a correctness evaluator. It records and signs public provenance facts so a user or the private Foundry can determine which public source/workflow produced an artifact and can independently verify its hashes and software bill of materials.

Private conformance corpora, evaluator heuristics, reverse-engineering evidence, private research, eligibility reasoning, credentials, and other value-bearing validator material do not belong in this action or its output.

## What it produces

`actions/release-trust` operates on a completed public build output directory and writes a separate trust-bundle directory containing:

- `foundry-checksums.sha256` — sorted canonical SHA-256 inventory of the public build output;
- `foundry-sbom.spdx.json` — SPDX JSON SBOM generated with Syft through the pinned Anchore SBOM action;
- `foundry-build-context.json` — public repository/source/workflow/run/Foundry-action identity;
- `foundry-provenance-attestation.json` — Sigstore/GitHub attestation bundle when attestation is enabled;
- `foundry-sbom-attestation.json` — SBOM attestation bundle when attestation is enabled;
- `foundry-trust-manifest.json` — hashes and sizes of every other trust-bundle file plus attestation URLs.

The action also uploads that directory as a GitHub workflow artifact for release attachment or later public/private ingestion.

## Caller requirements

The caller must be a public repository containing only source and build material already approved for public exposure.

For provenance and SBOM attestations, the caller job grants only the permissions required by GitHub attestation generation:

```yaml
permissions:
  contents: read
  id-token: write
  attestations: write
  artifact-metadata: write
```

If the product workflow also creates or updates a GitHub Release, it may separately require `contents: write`.

The public workflow must **not** receive a token, deploy key, PAT, GitHub App credential, or other credential capable of reading `windows-package-foundry-private`, a private product-development repository, private artifacts, or private validator evidence.

## Use from a product repository

Product repositories must pin the Foundry action to an exact 40-character commit SHA rather than `main`, a branch, or a mutable version tag.

Example after the Foundry trust action has been reviewed and merged:

```yaml
- name: Generate Foundry trust envelope
  uses: SemperSupra/windows-package-foundry/actions/release-trust@<FULL_FOUNDRY_COMMIT_SHA>
  with:
    artifact-root: ${{ github.workspace }}/dist
    subject-path: |
      ${{ github.workspace }}/dist/Product-Installer-*.exe
      ${{ github.workspace }}/dist/Product-Portable-*.zip
    output-directory: ${{ github.workspace }}/foundry-trust
    trust-artifact-name: foundry-release-trust-${{ github.ref_name }}
    attest: 'true'
```

The product remains responsible for its public build/test/package mechanics. The trust envelope deliberately acts on finished public output instead of embedding product-specific correctness knowledge.

## Verifying an artifact

A user who downloads a release artifact can verify GitHub's provenance association with the public product repository using GitHub CLI:

```text
gh attestation verify <artifact> -R SemperSupra/<product-repository>
```

The user can additionally compare the downloaded artifact with `foundry-checksums.sha256`, inspect `foundry-build-context.json`, and inspect the SBOM.

Successful verification means that GitHub can verify the artifact's signed provenance record for the named public repository. It does **not** prove that the software is correct, secure, appropriate for a particular environment, or that every dependency is trustworthy.

Private Foundry validation is an additional promotion gate. Where a public validation result is useful, the public projection may contain a sanitized verdict bound to the exact artifact hashes and policy identity. It must not publish the private validator corpus or the detailed private reasoning that produced that verdict.

## Public self-test

`.github/workflows/release-trust-selftest.yml` exercises the trust action on a deterministic fixture.

- Pull requests generate checksums, SBOM, build context, trust manifest, and workflow artifact but do not mint attestations.
- Pushes to `main` and manual dispatch additionally exercise GitHub provenance and SBOM attestations.

The workflow and the composite action use full commit SHAs for all external GitHub Actions. `scripts/Test-PublicFoundry.ps1` rejects mutable external action references in the public Foundry trust/workflow tree.

## MVP boundary

The initial MVP consumer is WinInspect. The intended sequence is:

```text
WinInspect public source/tag
  -> WinInspect public build/test/package
    -> Foundry public trust envelope
      -> WinInspect immutable public Release
        -> private Foundry provenance/validation gate
          -> generated public package metadata
            -> clean Windows client lifecycle proof
```

The MVP intentionally does not require byte-for-byte reproducible Windows builds, a second independent builder, a custom transparency log, a full SLSA certification program, or complex Windows code-signing infrastructure.