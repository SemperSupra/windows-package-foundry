#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Resolve-Path '.').Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$required = @(
    'actions/release-trust/action.yml',
    'actions/release-trust/scripts/New-FoundryTrustBundle.ps1',
    'actions/release-trust/scripts/Complete-FoundryTrustBundle.ps1',
    'scripts/Test-PublicFoundry.ps1',
    'scripts/Test-ReleaseTrustBundle.ps1',
    '.github/workflows/release-trust-selftest.yml',
    '.foundry/repository-role.json',
    'docs/trust-model.md'
)

foreach ($relative in $required) {
    $path = Join-Path $RepositoryRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required public Foundry artifact: $relative"
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

Write-Host 'Public Foundry structure and immutable action-pin validation passed.'
