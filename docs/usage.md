# Using Windows Package Foundry

This document is the public usage contract for humans, automation, and coding/operations agents.

Windows Package Foundry is the public execution and distribution plane. It exposes generic build/package/trust machinery and generated public-safe distribution metadata. Private package policy, private validation evidence, and product-specific evaluator knowledge remain authoritative in the private Foundry.

## External registry policy

Official/community registries such as Microsoft WinGet Community, Chocolatey Community, Scoop community buckets, and PortableApps.com are optional downstream mirrors or convenience channels.

They are **not** required for a Foundry release to be usable, are not the authoritative source of package policy, and must not become a release dependency merely because a community queue is slow or unresponsive.

The authoritative public artifact identity is the product's immutable public release plus its Foundry trust/provenance evidence. Generated Foundry distribution metadata may be consumed directly or later projected to an external registry when that extra channel is worth maintaining.

Direct product-release workflows must not hold private Foundry credentials or independently promote to external registries.

## Humans

### Verify a public release

For a Foundry-enabled product release:

1. identify the exact product tag/source commit;
2. inspect the public product build/release workflow and its run;
3. download the release artifact and Foundry trust files;
4. compare the artifact SHA-256 with `foundry-checksums.sha256`;
5. inspect `foundry-build-context.json` for repository, source, workflow, run, and Foundry action identity;
6. inspect `foundry-sbom.spdx.json` when dependency inventory matters;
7. verify GitHub provenance, for example:

```text
gh attestation verify <artifact> -R SemperSupra/<product-repository>
```

A successful provenance check establishes origin/process evidence, not software correctness or security. See `docs/trust-model.md`.

### Use generated package metadata

When `distribution/` contains a package projection, treat it as generated and non-authoritative. Follow the package-specific README/metadata in that projection for local/private installation or repository registration.

Do not assume an external community registry contains the newest approved Foundry package. The product release and generated Foundry projection are the primary public references.

## Product automation

A public product repository that has finished its normal build/test/package steps may call the reusable trust action. Pin it to an exact 40-character Foundry commit SHA:

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

Required attestation permissions and the complete action contract are documented in `docs/release-trust.md`.

Automation invariants:

- use immutable source/release identities;
- pin third-party Actions and cross-repository Foundry references to full commit SHAs;
- use minimal token permissions;
- do not give public workflows credentials that can read private Foundry/product state;
- keep private evaluator/conformance/domain knowledge out of public builder logic;
- do not independently hand-author generated `distribution/` records;
- do not treat external registry publication as a prerequisite for release usability.

Machine-readable repository zoning and authority are in `.foundry/repository-role.json`.

## Agents

Before changing this repository, agents must read:

1. `AGENTS.md`;
2. `README.md`;
3. this file;
4. `docs/trust-model.md`;
5. `.foundry/repository-role.json`;
6. the governing issue or pull request.

Agents may modify generic public infrastructure through a reviewed branch/PR. They must not independently modify generated distribution records or import private validation material.

If a requested change requires private eligibility decisions, private evaluator data, reverse-engineering evidence, credentials, private artifacts, or detailed private validation reasoning, stop that public implementation path and return the requirement to the private authoritative Foundry.

## Current capability boundary

The operational public capability currently available is the reusable release-trust envelope. Generated package-manager distribution is being added through the Foundry MVP vertical slice.

Until a generated projection exists for a product, use the product's immutable public release and trust evidence directly rather than inventing package metadata or depending on an external community registry submission.
