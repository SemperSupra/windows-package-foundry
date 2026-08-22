# Windows Package Foundry

Public build and packaging workspace for Windows applications that are safe to build in public CI.

## Current application: AU Companion

`apps/au-companion/` hosts the public source/build packaging for a read-only Assumption University (Thailand) student companion MVP.

### Public/private boundary

This repository may contain only:
- application source code;
- build and installer definitions;
- synthetic fixtures and tests;
- public protocol/configuration facts;
- release artifacts produced from the public source.

It must never contain:
- student credentials, MFA data, access/refresh tokens, cookies, or session material;
- private student mailbox content, grades, schedules, financial records, or exported datasets;
- authenticated captures/logs containing private student data;
- APKs, decompiled production application trees, or proprietary binary assets.

The AU Companion application processes authenticated student data only on the user's own machine. Public CI must be fully synthetic and require no AU/Microsoft credentials.

## CI policy

Use public GitHub Actions runners for build/test/release so the private integration repository does not spend its included private-repository Actions minutes. CI must not require repository secrets for normal pull-request builds.
