#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $OutputDirectory,
    [Parameter(Mandatory)] [bool] $AttestationsRequested,
    [string] $ProvenanceBundlePath,
    [string] $ProvenanceUrl,
    [string] $SbomBundlePath,
    [string] $SbomUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Content
    )
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

$output = [IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $output -PathType Container)) {
    throw "Trust output directory does not exist: $output"
}

foreach ($requiredName in @('foundry-checksums.sha256', 'foundry-build-context.json', 'foundry-sbom.spdx.json')) {
    $requiredPath = Join-Path $output $requiredName
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Missing required trust-bundle file: $requiredName"
    }
}

$provenanceFile = $null
$sbomAttestationFile = $null

if ($AttestationsRequested) {
    if ([string]::IsNullOrWhiteSpace($ProvenanceBundlePath) -or -not (Test-Path -LiteralPath $ProvenanceBundlePath -PathType Leaf)) {
        throw 'Provenance attestation was requested but no provenance bundle file was produced.'
    }
    if ([string]::IsNullOrWhiteSpace($SbomBundlePath) -or -not (Test-Path -LiteralPath $SbomBundlePath -PathType Leaf)) {
        throw 'SBOM attestation was requested but no SBOM attestation bundle file was produced.'
    }
    if ([string]::IsNullOrWhiteSpace($ProvenanceUrl) -or [string]::IsNullOrWhiteSpace($SbomUrl)) {
        throw 'Attestation URLs are required when attestations are requested.'
    }

    $provenanceFile = Join-Path $output 'foundry-provenance-attestation.json'
    $sbomAttestationFile = Join-Path $output 'foundry-sbom-attestation.json'
    Copy-Item -LiteralPath $ProvenanceBundlePath -Destination $provenanceFile -Force
    Copy-Item -LiteralPath $SbomBundlePath -Destination $sbomAttestationFile -Force
}

$inventory = @(
    Get-ChildItem -LiteralPath $output -File -Force |
        Where-Object Name -ne 'foundry-trust-manifest.json' |
        Sort-Object -Property Name |
        ForEach-Object {
            [ordered]@{
                path = $_.Name
                sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
                sizeBytes = $_.Length
            }
        }
)

$manifest = [ordered]@{
    schemaVersion = 1
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    attestationsRequested = $AttestationsRequested
    provenanceAttestationUrl = if ($AttestationsRequested) { $ProvenanceUrl } else { $null }
    sbomAttestationUrl = if ($AttestationsRequested) { $SbomUrl } else { $null }
    files = $inventory
}

$manifestPath = Join-Path $output 'foundry-trust-manifest.json'
Write-Utf8NoBom -Path $manifestPath -Content (($manifest | ConvertTo-Json -Depth 20) + "`n")

Write-Host "Foundry trust bundle finalized: $manifestPath"
