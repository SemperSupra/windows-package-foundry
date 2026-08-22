# Foundry client interface contract

## Purpose

Windows Package Foundry should be easy to consume without requiring users, scripts, or agents to understand Foundry internals. The preferred client experience is the normal interface of the package manager the user already chose.

The private Foundry remains authoritative for policy and validation. The public Foundry exposes approved public-safe artifacts, metadata, trust evidence, and client interfaces.

## Primary UX requirement

For an approved package, the steady-state install/update/remove path should use the package manager's native commands after at most one simple source/bootstrap step.

Examples of the intended shape:

```text
scoop bucket add semper-supra <public-foundry-repository>
scoop install semper-supra/<package>

choco source add -n=SemperSupraFoundry -s=<foundry-feed>
choco install <package> -s=SemperSupraFoundry

winget source add -n SemperSupraFoundry -a <foundry-rest-source> -t Microsoft.Rest
winget install --source SemperSupraFoundry --id <package-id>
```

Where a native remote source is not yet implemented, a local-manifest/local-folder fallback may be used for bring-up. That fallback is not the target UX.

Humans should not have to manually select hashes, discover release assets, edit generated manifests, or know the private validation workflow to install an approved package.

## Human interface

The public Foundry should provide a generated web UI that lets a user:

- browse/search approved packages;
- see version, source, license, release identity, and promotion state;
- copy the exact native install/update/remove commands for Scoop, Chocolatey, WinGet, and other supported clients;
- inspect trust/provenance evidence;
- reach the canonical upstream project/release;
- understand when a client path is unavailable or still pending lifecycle proof.

The web UI is a presentation layer over generated public state. It must not become package-policy authority.

## Automation interface

Automation should have stable, machine-readable public endpoints generated from the same approved package projection used by the human UI.

At minimum expose versioned JSON for:

- catalog/package identity;
- current approved version and immutable source identity;
- artifact URLs and hashes;
- supported package-manager projections;
- public promotion/verdict state;
- trust/provenance references;
- interface/schema version.

Automation must not scrape rendered HTML when structured public data is available.

## Agent interface

Agents must discover this contract through `AGENTS.md`, `README.md`, and `docs/usage.md` before changing public distribution behavior.

Agents should optimize toward native package-manager consumption and a single generated source of public package state. They must not solve client UX by duplicating private policy or hand-authoring generated package records.

## GitHub Pages role

A GitHub Pages site is appropriate for:

- a generated single-page application for humans;
- static documentation;
- static JSON catalog and schema files;
- bootstrap scripts/configuration examples;
- trust/provenance links;
- static Scoop bucket content and generated manifest files.

GitHub Pages is static hosting. A browser SPA cannot act as a server for package-manager requests made by `winget`, `choco`, or other native clients.

## Protocol adapter requirement

Some native package-manager source protocols require request processing that static hosting cannot provide.

### Scoop

Scoop's native bucket is Git-backed/static. Prefer a directly consumable generated bucket in the public Foundry repository. No separate REST backend is required.

### WinGet

Local generated manifests are acceptable during MVP bring-up. The target native remote-source UX requires a WinGet REST source adapter. The REST protocol includes request/response behavior such as manifest search and therefore is not implemented by a static Pages site alone.

### Chocolatey

A local folder/feed is acceptable during MVP bring-up. The target native remote-source UX requires a NuGet-compatible HTTP package feed (OData/NuGet protocol as supported by the selected Chocolatey client version). Static Pages files alone are not a complete Chocolatey HTTP source.

### PortableApps and direct release

Static generated downloads/metadata may be sufficient where the client does not require a repository protocol. These remain optional interfaces and must not become Foundry authority.

## Preferred web/API architecture

Use one generated public package model as the source for all public interfaces:

```text
private approved state
        |
        v
sanitized public projection
        |
        +--> generated package-manager metadata
        +--> generated static JSON catalog
        +--> generated GitHub Pages SPA
        +--> thin stateless protocol adapters where required
```

Protocol adapters must be public, generic, stateless where practical, and unable to read private Foundry state. They should consume only the sanitized public projection.

A small serverless/edge adapter is preferable to introducing a stateful package-management service when the protocol can be deterministically answered from generated public catalog data.

## DX requirements

- one authoritative generated public package model;
- deterministic regeneration;
- no manual duplication between SPA, JSON API, and package-manager metadata;
- native client commands as the primary documented path;
- copy/paste bootstrap/install commands;
- explicit schema/interface versions for automation;
- fail closed when promotion/lifecycle proof is incomplete;
- external community registries remain optional mirrors.
