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
    '.github/workflows/release-trust-selftest.yml',
    '.foundry/repository-role.json',
    'docs/usage.md',
    'docs/client-interface-contract.md',
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

Write-Host 'Public Foundry structure, usage/client contracts, and immutable action-pin validation passed.'
