# Public Trust and Provenance Model

## Purpose

Windows Package Foundry is designed so users do not have to rely only on publisher reputation to understand how a public release was produced.

The public side of the system exposes generic build/package machinery and release evidence while a separate private validation plane may apply deeper product-specific checks before release approval.

The boundary is intentional: **make provenance inspectable without publishing all private validator knowledge.**

## What users should be able to inspect

For a mature public release, the target evidence chain is:

```text
public source commit/tag
        |
        v
public caller workflow
        |
        v
immutable Foundry workflow revision
        |
        v
ordinary public tests + build logs
        |
        v
artifact + SHA-256 + SBOM + provenance/attestation
```

This allows a user to assess questions such as:

- What source was built?
- What workflow built it?
- What dependencies/toolchain were used?
- What ordinary public tests ran?
- What artifact hash was published?
- Is there verifiable provenance linking the release artifact to the public build?

## What this does not prove

A transparent public build does not prove that software is:

- correct;
- secure;
- free of defects;
- compatible with every environment;
- equivalent to all private validation results.

Public provenance is evidence about **origin and process**. It is not a mathematical or security proof of behavior.

## Private validation

A private validation plane may hold higher-value material such as deep conformance corpora, adversarial/negative cases, fuzz discoveries, private golden outputs, reverse-engineering evidence, evaluator heuristics, failure fingerprints, private provenance research, and unpublished security findings.

Those assets do not need to be public for the public build to remain inspectable.

When useful, a release may expose a sanitized validation verdict bound to an immutable release/artifact identity. The rule is:

> Publish the verdict when useful; do not publish the private examination merely to make the verdict look more transparent.

Private validation is an additional release gate, not a substitute for public provenance.

## Public build safety boundary

Public workflows must not receive credentials capable of reading private product or Foundry repositories, private releases, private artifacts, or private validation data.

The public builder should remain domain-generic. It may compile, package, test ordinary public behavior, hash, generate SBOM/provenance, attest, and publish. It should not need private domain-specific correctness knowledge.

## Private-to-public airlock

Public source and release inputs are selected constructively from already-approved public-safe material.

The project explicitly rejects the pattern of copying a private repository and trying to sanitize it by deleting known-private paths afterward.

## Practical assurance target

The initial target is:

**rebuildable + provenance-verifiable + dependency-pinned**

Controls with strong value-to-effort ratio include:

- immutable source/release identity;
- reusable workflows and third-party Actions pinned to immutable SHAs;
- locked dependencies/toolchains where practical;
- ordinary public tests and logs;
- SHA-256 release files;
- SBOM generation;
- artifact attestations;
- minimal workflow permissions;
- protected release refs;
- separate private deep-validation approval.

More expensive controls such as mandatory byte-identical Windows builds, independent second builders, full supply-chain certification programs, custom transparency services, complex signing infrastructure, or cryptographic proofs of private validation are deferred until the additional assurance justifies their cost.

## Trust philosophy

The system is intended to support a skeptical user rather than ask for blind trust:

- inspect the source;
- inspect the workflow;
- inspect the ordinary tests;
- verify hashes/provenance;
- rebuild when desired;
- treat private validation as additional publisher evidence rather than public proof.
