#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $BundleDirectory,
    [Parameter(Mandatory)] [string] $ArtifactRoot,
    [Parameter(Mandatory)] [bool] $ExpectAttestations
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

$bundle = [IO.Path]::GetFullPath($BundleDirectory)
$artifactRootFull = [IO.Path]::GetFullPath($ArtifactRoot)

foreach ($name in @(
    'foundry-checksums.sha256',
    'foundry-build-context.json',
    'foundry-sbom.spdx.json',
    'foundry-trust-manifest.json'
)) {
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $bundle $name) -PathType Leaf) -Message "Missing trust-bundle file: $name"
}

$artifactEntries = @(
    Get-ChildItem -LiteralPath $artifactRootFull -Recurse -File -Force |
        ForEach-Object {
            [pscustomobject]@{
                relative = [IO.Path]::GetRelativePath($artifactRootFull, $_.FullName).Replace('\', '/')
                hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
            }
        } |
        Sort-Object relative
)
Assert-True -Condition ($artifactEntries.Count -gt 0) -Message 'Self-test artifact root is unexpectedly empty.'

$checksumPath = Join-Path $bundle 'foundry-checksums.sha256'
$checksumLines = @(Get-Content -LiteralPath $checksumPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
Assert-True -Condition ($checksumLines.Count -eq $artifactEntries.Count) -Message 'Checksum manifest file count does not match artifact inventory.'

$expectedLines = @($artifactEntries | ForEach-Object { "$($_.hash)  $($_.relative)" })
for ($i = 0; $i -lt $expectedLines.Count; $i++) {
    Assert-True -Condition ($checksumLines[$i] -ceq $expectedLines[$i]) -Message "Checksum manifest mismatch at line $($i + 1)."
}

$context = Get-Content -LiteralPath (Join-Path $bundle 'foundry-build-context.json') -Raw | ConvertFrom-Json
Assert-True -Condition ($context.schemaVersion -eq 1) -Message 'Build context schema version mismatch.'
Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$context.repository)) -Message 'Build context repository is missing.'
Assert-True -Condition ([string]$context.sourceSha -match '^[0-9a-fA-F]{40,64}$') -Message 'Build context source SHA is invalid.'
Assert-True -Condition ($context.inventoriedFileCount -eq $artifactEntries.Count) -Message 'Build context file count mismatch.'
Assert-True -Condition ($context.checksumManifest -eq 'foundry-checksums.sha256') -Message 'Build context checksum manifest name drifted.'
Assert-True -Condition ([string]$context.checksumManifestSha256 -match '^[0-9a-f]{64}$') -Message 'Build context checksum manifest hash is invalid.'

$sbom = Get-Content -LiteralPath (Join-Path $bundle 'foundry-sbom.spdx.json') -Raw | ConvertFrom-Json
Assert-True -Condition ([string]$sbom.spdxVersion -match '^SPDX-') -Message 'SBOM is not SPDX JSON.'

$manifest = Get-Content -LiteralPath (Join-Path $bundle 'foundry-trust-manifest.json') -Raw | ConvertFrom-Json
Assert-True -Condition ($manifest.schemaVersion -eq 1) -Message 'Trust manifest schema version mismatch.'
Assert-True -Condition ($manifest.attestationsRequested -eq $ExpectAttestations) -Message 'Trust manifest attestation expectation mismatch.'

$manifestEntries = @($manifest.files)
Assert-True -Condition ($manifestEntries.Count -ge 3) -Message 'Trust manifest has too few files.'
foreach ($entry in $manifestEntries) {
    $path = Join-Path $bundle $entry.path
    Assert-True -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Message "Trust manifest references missing file: $($entry.path)"
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    Assert-True -Condition ($actual -ceq [string]$entry.sha256) -Message "Trust manifest hash mismatch: $($entry.path)"
}

$provenancePath = Join-Path $bundle 'foundry-provenance-attestation.json'
$sbomAttestationPath = Join-Path $bundle 'foundry-sbom-attestation.json'
if ($ExpectAttestations) {
    Assert-True -Condition (Test-Path -LiteralPath $provenancePath -PathType Leaf) -Message 'Expected provenance attestation bundle is missing.'
    Assert-True -Condition (Test-Path -LiteralPath $sbomAttestationPath -PathType Leaf) -Message 'Expected SBOM attestation bundle is missing.'
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$manifest.provenanceAttestationUrl)) -Message 'Provenance attestation URL is missing.'
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$manifest.sbomAttestationUrl)) -Message 'SBOM attestation URL is missing.'
} else {
    Assert-True -Condition (-not (Test-Path -LiteralPath $provenancePath)) -Message 'PR self-test unexpectedly created a provenance attestation bundle.'
    Assert-True -Condition (-not (Test-Path -LiteralPath $sbomAttestationPath)) -Message 'PR self-test unexpectedly created an SBOM attestation bundle.'
}

Write-Host 'Foundry release trust bundle validation passed.'
