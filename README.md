# Windows Package Foundry

Public Windows **execution and distribution plane** for SemperSupra applications and eligible external packages.

This repository is intentionally observable. Users should be able to inspect the generic build/package machinery used for public releases and use that visibility as part of their own trust decision.

It is **not** the authoritative repository for private package policy, private validation evidence, or product-specific evaluator knowledge.

## How to use this repository

- **Humans:** start with `docs/usage.md`; `docs/client-interface-contract.md` defines the native package-manager and web UI experience; use `docs/trust-model.md` to understand what the public evidence does and does not prove.
- **Product/release automation:** use the immutable caller contract in `docs/release-trust.md`, the client/machine interface contract in `docs/client-interface-contract.md`, and the machine-readable zoning in `.foundry/repository-role.json`.
- **Agents:** read `AGENTS.md`, `.github/copilot-instructions.md`, `docs/usage.md`, and `docs/client-interface-contract.md` before proposing changes.

The target client UX is ordinary native package-manager usage after at most one simple source/bootstrap step. The same generated public package model should drive the human web UI, structured automation data, package-manager metadata, and any thin protocol adapters.

External community registries such as WinGet Community, Chocolatey Community, Scoop buckets, and PortableApps.com are optional downstream mirrors or convenience channels. They are not authoritative Foundry state and are not required for a Foundry release to be usable.

## MVP release-trust tooling

The first operational public-execution capability is `actions/release-trust`.

It is designed to wrap a completed public product build with a reusable, inspectable trust envelope rather than replace the product's working build system. The action can produce:

- a deterministic SHA-256 inventory of the public build output;
- an SPDX JSON SBOM;
- a public build-context manifest tying the output to repository/source/workflow/Foundry identities;
- GitHub/Sigstore provenance and SBOM attestations;
- a self-hashed trust-bundle manifest;
- a workflow artifact that can be attached to a public release or ingested by the private validation plane.

All external GitHub Actions used by the Foundry trust path are pinned by full commit SHA and CI rejects mutable action references in this execution surface.

See `docs/release-trust.md` for the caller contract, required permissions, output format, and independent verification procedure.

The initial MVP consumer is **WinInspect**. The target proof is:

```text
WinInspect public source/tag
  -> public Windows build/test/package
    -> Foundry public trust envelope
      -> immutable public release
        -> private Foundry provenance + validation gate
          -> generated public package metadata
            -> clean Windows client lifecycle proof
```

The Foundry MVP is not considered complete until that whole chain is demonstrated.

## Repository role

This public repository contains two distinct zones.

### 1. Generic public execution infrastructure — hand-authored and reviewed

This zone may contain:

- reusable/composite GitHub Actions and workflows;
- generic Windows build/package templates;
- portable ZIP and installer helpers;
- checksum, SBOM, provenance, and artifact-attestation helpers;
- ordinary public unit/integration/smoke-test plumbing;
- public release-verification helpers;
- public documentation.

This code is public by design so users and contributors can inspect how public release artifacts are produced.

### 2. Public package/distribution metadata — generated and non-authoritative

The distribution zone may contain generated public-safe metadata such as:

- WinGet-style manifests;
- Scoop metadata;
- Chocolatey metadata;
- public package catalog/index data;
- public provenance/role markers.

Generated distribution metadata is projected from the private authoritative Foundry state and must not be independently hand-authored here.

The preferred layout is conceptually:

```text
windows-package-foundry/
|
|-- .github/workflows/        public generic infrastructure
|-- actions/                  reusable public trust/release actions
|-- tooling/                  public generic infrastructure
|-- templates/                public generic infrastructure
|-- docs/                     public documentation
`-- distribution/             generated, non-authoritative
    |-- winget/
    |-- scoop/
    |-- chocolatey/
    `-- catalog/
```

Exact paths may evolve; the semantic boundary must not.

## Generator–validator boundary

The project follows a generator–validator separation:

- the **public builder** knows generic build/package mechanics;
- the **private validation plane** may apply deeper product-specific compatibility, adversarial, conformance, provenance, or evaluation knowledge before a release is approved.

Public build infrastructure must not require private evaluator corpora, private reverse-engineering evidence, private golden-answer sets, private credentials, private repository access, or other value-bearing private material.

Where a private validation result is surfaced publicly, the preferred pattern is to publish a sanitized verdict bound to an immutable artifact/release identity — not the private examination that produced the verdict.

## What public build transparency proves — and what it does not

The goal is to let a skeptical user inspect or verify, as implemented for a product:

- the exact public source commit/tag;
- the exact public workflow revision;
- build dependencies/toolchain inputs;
- ordinary public test results;
- build logs;
- release hashes;
- SBOM/provenance;
- artifact attestations.

This supports **provenance transparency**: users can see how the shipped artifact relates to public source and public build machinery.

It does **not** by itself prove that software is correct, secure, bug-free, or equivalent to the private validation process.

See `docs/trust-model.md`.

## Private-to-public airlock

Public source/release material must cross an explicit constructive allowlist boundary.

The intended pattern is:

```text
private development state
        |
        | explicitly select already-approved public-safe material
        v
public source/release repository
        |
        | public caller workflow
        v
public Foundry build/package machinery
        |
        v
public candidate release
        |
        | separate private eligibility/deep-validation gate
        v
approved public distribution metadata
```

Do not publish by copying a private repository tree and then deleting known-private paths.

Public workflows must not receive credentials that allow them to read private Foundry repositories, private product repositories, private releases, or private artifacts.

## GitHub Actions and build observability

Public product repositories are intended to call reusable/composite tooling hosted here for generic Windows build/release trust work.

Under GitHub's current billing model, reusable-workflow execution is billed to the **caller**. Having the caller itself be public preserves the standard public-repository hosted-runner cost advantage while also making the build path inspectable.

The billing benefit is an optimization, not a security invariant. The build process should remain understandable and locally reproducible if GitHub pricing or product policy changes.

For release workflows, require or prefer:

- immutable public source/tag identity;
- third-party Actions pinned to full commit SHAs;
- cross-repository Foundry references pinned to immutable commit SHAs;
- minimal token permissions;
- secret-free, non-privileged execution for untrusted pull requests;
- locked dependencies/toolchains where practical;
- hashes, SBOMs, provenance, and artifact attestations where low-friction.

## Reproducibility target

The practical MVP target is:

**rebuildable + provenance-verifiable + dependency-pinned**

Bit-for-bit Windows reproducibility is useful where cheap, but it is not required merely for appearance's sake. Signing, independent second builders, full SLSA certification, custom transparency services, and complex cryptographic proofs are added only when their incremental assurance justifies the operational complexity.

## Source and release ownership

Application-specific source should normally live in that application's own public source/release repository. The application repository remains the canonical source/release location for its public binaries and source snapshots.

Windows Package Foundry provides reusable public build/package/trust infrastructure and public-safe distribution metadata. It does not become a source-code mirror for every product.

## Machine and agent contracts

- `docs/usage.md` — public usage contract for humans, automation, and agents;
- `docs/client-interface-contract.md` — native package-manager UX, generated web/JSON interfaces, and protocol-adapter boundary;
- `.foundry/repository-role.json` — machine-readable public repository role and zoning;
- `AGENTS.md` — contributor/agent safety and authorship rules;
- `.github/copilot-instructions.md` — coding-agent bootstrap rules;
- `docs/trust-model.md` — user-facing trust and provenance model;
- `docs/release-trust.md` — operational public release-trust contract.
