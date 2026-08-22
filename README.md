# Windows Package Foundry

Public build and packaging workspace for Windows applications that are safe to build in public CI.

This repository is intentionally **not** the canonical development/source repository for AU Companion. AU Companion development remains private; any future public deployment repository should receive only a release-safe snapshot through an explicit airlock/promotion step.

## CI policy

Public GitHub Actions may be used for build/test/package work on release-safe public snapshots so private repositories do not consume their included private-repository Actions minutes.

Public CI must never receive credentials, private student data, authenticated captures, or private-repository checkout credentials merely to build an application.
