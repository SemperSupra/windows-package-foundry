# Windows Package Foundry

Public Windows build, packaging, and distribution infrastructure for applications that are safe to build in public CI.

This repository is intentionally **not** the canonical development/source repository for AU Companion or other private-development applications. Application development may remain private; public deploy repositories receive only release-safe snapshots through an explicit airlock/promotion step.

## Intended role

Windows Package Foundry may provide reusable, versioned infrastructure for multiple Windows applications:

- GitHub Actions reusable workflows for restore/test/publish/package;
- self-contained .NET build templates;
- portable ZIP packaging;
- reversible per-user installer templates;
- checksum/provenance generation;
- SBOM generation;
- optional signing hooks that fail closed when signing material is absent;
- future WinGet manifest generation/submission helpers;
- a public catalog/index of Windows releases and their canonical application repositories;
- reproducible release verification helpers.

Application-specific public source should normally live in that application's own public deploy repository. For AU Companion that repository is intended to be `SemperSupra/au-companion`.

## Distribution model

Preferred MVP pattern:

```text
private canonical dev repo
        |
        | deterministic release airlock
        v
public app deploy/source repo
        |
        | version-pinned reusable workflow/templates
        v
Windows Package Foundry infrastructure
        |
        v
app repo GitHub Release: source + portable ZIP + installer + checksums
```

The app repository remains the canonical release location initially. The foundry may later add a centralized release catalog/index when that provides enough value to justify the extra automation.

Avoid cross-repository write credentials for MVP. Reusable workflows/templates are preferable to having the foundry push releases into another repository.

## Public/private boundary

This repository may contain only generic/public build and distribution material.

It must never contain:
- student credentials, MFA data, access/refresh tokens, cookies, or session material;
- private student mailbox content, grades, schedules, financial records, or exported datasets;
- authenticated captures/logs containing private student data;
- APKs, decompiled production application trees, or proprietary binary assets;
- private AU/SPARK provider packs, reverse-engineering evidence, undocumented endpoint inventories, auth-exchange recipes, or other private interoperability value;
- credentials that allow a public workflow to read a private development repository merely to obtain source.

## CI policy

Public GitHub Actions may be used for build/test/package work on release-safe public snapshots so private repositories do not consume their included private-repository Actions minutes.

Public CI must be fully synthetic/non-secret by default. Applications that require private runtime configuration should load it only after installation on the authorized end-user machine, never during the public build.

## Reproducibility principle

A public release binary should correspond to the public source snapshot used to build it. Do not publish binaries that embed hidden private source or private provider knowledge absent from the accompanying source. Private runtime/provider configuration should be delivered as a separately versioned private artifact if needed.
