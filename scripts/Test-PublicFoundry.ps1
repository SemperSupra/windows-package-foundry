#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Resolve-Path '.').Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$required = @(
    'README.md',
    'AGENTS.md',
    '.github/copilot-instructions.md',
    'actions/release-trust/action.yml',
    'actions/release-trust/scripts/New-FoundryTrustBundle.ps1',
    'actions/release-trust/scripts/Complete-FoundryTrustBundle.ps1',
    'scripts/Test-PublicFoundry.ps1',
    'scripts/Test-ReleaseTrustBundle.ps1',
    'scripts/New-PublicPackageProjection.ps1',
    'scripts/Test-WinGetClientLifecycle.ps1',
    'scripts/Test-WinGetPortableLifecycle.ps1',
    '.github/workflows/release-trust-selftest.yml',
    '.github/workflows/winspect-mvp-client-lifecycle.yml',
    '.foundry/repository-role.json',
    'tests/fixtures/public-package.json',
    'docs/usage.md',
    'docs/client-interface-contract.md',
    'docs/client-interface-redteam.md',
    'docs/trust-model.md',
    'docs/release-trust.md'
)

foreach ($relative in $required) {
    $path = Join-Path $RepositoryRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required public Foundry artifact: $relative"
    }
}

$usageText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'docs/usage.md') -Raw
foreach ($requiredUsageToken in @(
    '## Humans',
    '## Product automation',
    '## Agents',
    'Client UX and DX contract',
    'docs/client-interface-contract.md',
    'External registry policy',
    'optional downstream mirrors',
    'must not become a release dependency',
    'gh attestation verify',
    '.foundry/repository-role.json'
)) {
    if (-not $usageText.Contains($requiredUsageToken, [StringComparison]::Ordinal)) {
        throw "Public usage contract lost required marker: $requiredUsageToken"
    }
}

$clientText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'docs/client-interface-contract.md') -Raw
foreach ($requiredClientToken in @(
    '## Primary UX requirement',
    'package manager''s native commands',
    '## Human interface',
    '## Automation interface',
    '## Agent interface',
    '## GitHub Pages role',
    'static hosting',
    '## Protocol adapter requirement',
    '### Scoop',
    '### WinGet',
    '### Chocolatey',
    'one generated public package model',
    'thin stateless protocol adapters'
)) {
    if (-not $clientText.Contains($requiredClientToken, [StringComparison]::Ordinal)) {
        throw "Public client interface contract lost required marker: $requiredClientToken"
    }
}

$redTeamText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'docs/client-interface-redteam.md') -Raw
foreach ($requiredRedTeamToken in @(
    'Prefer static generation over a framework SPA',
    'Reject the static-NuGet-v3 shortcut',
    'Generate atomically',
    'Fail closed on lifecycle/promotion state',
    'WinGet REST source adapter',
    'Chocolatey/NuGet HTTP feed adapter'
)) {
    if (-not $redTeamText.Contains($requiredRedTeamToken, [StringComparison]::Ordinal)) {
        throw "Client-interface red-team record lost required marker: $requiredRedTeamToken"
    }
}

$agentsText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'AGENTS.md') -Raw
foreach ($requiredAgentToken in @('docs/usage.md', 'docs/client-interface-contract.md', 'native package-manager consumption')) {
    if (-not $agentsText.Contains($requiredAgentToken, [StringComparison]::Ordinal)) {
        throw "AGENTS.md lost required client-interface marker: $requiredAgentToken"
    }
}

$copilotText = Get-Content -LiteralPath (Join-Path $RepositoryRoot '.github/copilot-instructions.md') -Raw
foreach ($requiredCopilotToken in @('docs/client-interface-contract.md', 'native package-manager consumption', 'GitHub Pages SPA')) {
    if (-not $copilotText.Contains($requiredCopilotToken, [StringComparison]::Ordinal)) {
        throw "Copilot instructions lost required client-interface marker: $requiredCopilotToken"
    }
}

$scanPaths = @(
    Join-Path $RepositoryRoot 'actions',
    Join-Path $RepositoryRoot '.github/workflows'
)

$usesPattern = '(?m)^\s*-?\s*uses:\s*([^\s#]+)'
foreach ($root in $scanPaths) {
    foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File -Include *.yml,*.yaml -ErrorAction Stop)) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        foreach ($match in [regex]::Matches($text, $usesPattern)) {
            $reference = $match.Groups[1].Value.Trim('"', "'")
            if ($reference.StartsWith('./', [StringComparison]::Ordinal) -or $reference.StartsWith('docker://', [StringComparison]::OrdinalIgnoreCase)) {
                continue
            }
            if ($reference -notmatch '@[0-9a-fA-F]{40}$') {
                throw "External action is not pinned by full commit SHA in $($file.FullName): $reference"
            }
        }
    }
}

$actionText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'actions/release-trust/action.yml') -Raw
foreach ($requiredToken in @(
    'foundry-checksums.sha256',
    'foundry-sbom.spdx.json',
    'foundry-build-context.json',
    'foundry-trust-manifest.json',
    'actions/attest@',
    'anchore/sbom-action@',
    'actions/upload-artifact@'
)) {
    if (-not $actionText.Contains($requiredToken, [StringComparison]::Ordinal)) {
        throw "Release trust action lost required capability marker: $requiredToken"
    }
}

$forbidden = @(
    'windows-package-foundry-private',
    'WINGET_GITHUB_TOKEN',
    'CHOCO_API_KEY',
    'SCOOP_GITHUB_TOKEN',
    'pull_request_target'
)
foreach ($token in $forbidden) {
    if ($actionText.Contains($token, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Release trust action contains forbidden private/promotion capability marker: $token"
    }
}

# Prove one approved public model generates all client/human surfaces and that
# promotion drift fails closed.
$fixture = Join-Path $RepositoryRoot 'tests/fixtures/public-package.json'
$generator = Join-Path $RepositoryRoot 'scripts/New-PublicPackageProjection.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('foundry-public-projection-' + [guid]::NewGuid().ToString('N'))
try {
    & $generator -InputPath $fixture -OutputRoot $tempRoot

    foreach ($relative in @(
        'catalog/v1/catalog.json',
        'catalog/v1/packages/fixture-app.json',
        'bucket/fixture-app.json',
        'distribution/winget/Example.FixtureApp/1.2.3/Example.FixtureApp.yaml',
        'chocolatey/packages/fixture-app/fixture-app.nuspec',
        'chocolatey/packages/fixture-app/tools/chocolateyInstall.ps1',
        'site/packages/fixture-app/index.html'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $tempRoot $relative) -PathType Leaf)) {
            throw "Projection generator did not create required output: $relative"
        }
    }

    $scoop = Get-Content -LiteralPath (Join-Path $tempRoot 'bucket/fixture-app.json') -Raw | ConvertFrom-Json
    if ($scoop.version -ne '1.2.3' -or $scoop.architecture.'64bit'.hash -ne ('b' * 64)) {
        throw 'Generated Scoop fixture lost version/hash binding.'
    }
    if (@($scoop.bin) -notcontains 'App/Fixture/fixture.exe') {
        throw 'Generated Scoop fixture lost portable archive-relative binary path.'
    }

    $wingetText = Get-Content -LiteralPath (Join-Path $tempRoot 'distribution/winget/Example.FixtureApp/1.2.3/Example.FixtureApp.yaml') -Raw
    foreach ($token in @(
        '# yaml-language-server: $schema=https://aka.ms/winget-manifest.singleton.1.10.0.schema.json',
        'Example.FixtureApp',
        "InstallerType: 'zip'",
        "NestedInstallerType: 'portable'",
        "RelativeFilePath: 'App\Fixture\fixture.exe'",
        "PortableCommandAlias: 'fixture'",
        ('b' * 64),
        'ManifestVersion: 1.10.0'
    )) {
        if (-not $wingetText.Contains($token, [StringComparison]::Ordinal)) {
            throw "Generated WinGet fixture lost required token: $token"
        }
    }
    if ($wingetText.Contains("Scope: 'user'", [StringComparison]::Ordinal)) {
        throw 'Portable WinGet projection contains unsupported Scope metadata.'
    }
    if ($wingetText.Contains(('a' * 64), [StringComparison]::Ordinal)) {
        throw 'Portable WinGet projection unexpectedly uses the NSIS installer hash.'
    }

    $pendingPath = Join-Path $tempRoot 'pending.json'
    $pending = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
    $pending.package.state.promotion = 'pending-client-lifecycle-proof'
    $pending | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $pendingPath -Encoding utf8NoBOM
    $rejected = $false
    try {
        & $generator -InputPath $pendingPath -OutputRoot (Join-Path $tempRoot 'should-not-exist')
    } catch {
        if ($_.Exception.Message -match 'Installable projection denied') {
            $rejected = $true
        } else {
            throw
        }
    }
    if (-not $rejected) {
        throw 'Projection generator accepted a package without lifecycle/promotion approval.'
    }
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Host 'Public Foundry structure, usage/client contracts, projection generation, and immutable action-pin validation passed.'
