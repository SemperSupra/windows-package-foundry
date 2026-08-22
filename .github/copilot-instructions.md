# Coding Agent Instructions

Read `AGENTS.md`, `README.md`, `docs/trust-model.md`, and `.foundry/repository-role.json` before proposing changes.

Key invariants:

- this repository is a public execution and distribution plane, not the private policy/validation authority;
- generic public build/package infrastructure may be hand-authored and reviewed;
- generated package/distribution metadata remains non-authoritative and must not be independently authored;
- public builder logic must remain generic and must not absorb private evaluator/conformance/domain knowledge;
- public workflows must not receive credentials capable of reading private product or Foundry repositories, releases, issues, or artifacts;
- public provenance transparency is not proof of correctness/security;
- private-to-public publication is constructive/allowlist-based, never copy-private-then-delete;
- for release-critical workflows, pin third-party Actions and cross-repository reusable workflows to immutable commit SHAs and use minimal token permissions.

If a requested implementation needs private validator data, private reverse-engineering evidence, private golden/fuzz/adversarial corpora, private credentials, or private artifacts, do not solve it in this repository. Return the decision/input requirement to the private authoritative Foundry process.
