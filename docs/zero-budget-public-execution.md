# Zero-budget public execution strategy

Status: operational continuity guidance

The private Foundry is an authority/value plane, not a compute plane. When the private repository has no GitHub-hosted Actions minutes available, development should continue by keeping all generic or heavyweight execution in public repositories and preserving the private gate rather than weakening it.

## Public execution remains authoritative for public mechanics

The public Foundry may continue to run, on standard public GitHub-hosted runners:

- immutable release/hash verification;
- package-manager projection validation;
- WinGet lifecycle proof;
- Scoop lifecycle proof;
- Chocolatey local-feed lifecycle proof;
- static catalog/site generation;
- generic trust/provenance presentation.

WinInspect, as a public product repository, may continue to run its build, test, package, release-trust, and packaged-installer lifecycle workflows publicly.

## Private work during hosted-minute exhaustion

Private policy/evaluator work may be developed and run locally against an exact commit. Local evidence is useful for development continuity but does not silently convert a pending promotion into an approved promotion.

The private authority decision remains explicit and fail-closed. Once a self-hosted runner or private hosted minutes are available, replay the same private inputs and validators to create durable CI evidence.

## Boundary rule

Do not move specialized evaluator logic, private evidence, failure fingerprints, or authority decisions into a public repository merely to obtain free execution. Move generic mechanics public; keep specialized judgment private.

## Current WinInspect MVP sequence

1. public WinInspect produces immutable release subjects and product lifecycle evidence;
2. public Foundry proves each native client against those exact subjects;
3. private Foundry evaluates the immutable public evidence and records promotion state;
4. private Foundry emits only a sanitized approved model;
5. public Foundry deterministically generates native package-manager and human/machine catalog surfaces from that model.
