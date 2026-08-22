# Public Foundry Agent Contract

This repository is the **public execution and distribution plane** for Windows Package Foundry.

Before changing anything, read:

1. `README.md`;
2. `docs/trust-model.md`;
3. `.foundry/repository-role.json`;
4. the governing issue or pull request.

## Repository zones

Treat the repository as two semantic zones:

### Generic execution zone

May be hand-authored and reviewed publicly:

- reusable workflows;
- generic build/package tooling;
- generic templates;
- ordinary public tests;
- checksum/SBOM/provenance helpers;
- public documentation.

This zone must remain domain-generic and public-safe.

### Distribution zone

Generated and non-authoritative:

- WinGet/Scoop/Chocolatey metadata;
- public package catalog/index data;
- generated provenance/role markers.

Do not independently hand-author generated package records or eligibility decisions here.

## Generator-validator boundary

The public builder knows **build/package mechanics**. Product-specific private correctness knowledge belongs to the private validation plane.

Do not move into this repository:

- private validator/evaluator corpora;
- deep conformance/adversarial/golden/fuzz material;
- reverse-engineering evidence or private domain maps;
- unpublished security findings;
- credentials, tokens, private URLs, cookies, private artifacts, or entitlement data;
- private eligibility evidence that is not intentionally public.

Preserve the rule: **publish the verdict, not the exam**.

## Public build trust rules

Public build visibility establishes provenance/inspectability, not proof of correctness or security.

For release-critical workflows:

- use immutable source/release identities;
- pin third-party Actions to full commit SHAs;
- pin reusable cross-repository workflows to immutable commit SHAs;
- use minimal token permissions;
- keep untrusted pull-request execution secret-free and non-privileged;
- do not grant credentials that can read private Foundry/product repositories or private artifacts;
- prefer locked dependencies/toolchains where practical;
- emit hashes, SBOM/provenance, and attestations where useful and low-friction.

## Airlock

Public inputs must be selected constructively from material already approved as public-safe.

Never copy/archive a private tree and then delete known-private files before publishing.

## Coordination

- do not work directly on `main`;
- use a branch and pull request for reviewed changes;
- do not edit generated distribution output independently;
- keep generic infrastructure and generated distribution concerns separate;
- record validation and provenance for release-critical changes;
- if a requested change appears to require private knowledge or private credentials, stop that path and move the decision back to the private authoritative Foundry process.
