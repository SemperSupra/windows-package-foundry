#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $InputPath,

    [Parameter(Mandatory)]
    [string] $OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require-Value {
    param([object] $Value, [string] $Name)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        throw "Missing required public projection value: $Name"
    }
}

function Assert-Sha256 {
    param([string] $Value, [string] $Name)
    if ($Value -notmatch '^[0-9a-fA-F]{64}$') {
        throw "$Name must be a 64-character SHA-256 value."
    }
}

function Quote-Yaml {
    param([string] $Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Escape-Xml {
    param([string] $Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

function Escape-Html {
    param([string] $Value)
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$model = Get-Content -LiteralPath $resolvedInput -Raw | ConvertFrom-Json

if ($model.schemaVersion -ne 1) {
    throw 'Unsupported public package schemaVersion; expected 1.'
}

foreach ($pair in @(
    @($model.package.slug, 'package.slug'),
    @($model.package.identity.id, 'package.identity.id'),
    @($model.package.identity.name, 'package.identity.name'),
    @($model.package.identity.publisher, 'package.identity.publisher'),
    @($model.package.identity.description, 'package.identity.description'),
    @($model.package.identity.homepage, 'package.identity.homepage'),
    @($model.package.identity.license, 'package.identity.license'),
    @($model.package.release.version, 'package.release.version'),
    @($model.package.release.tag, 'package.release.tag'),
    @($model.package.release.repository, 'package.release.repository'),
    @($model.package.release.sourceSha, 'package.release.sourceSha'),
    @($model.package.release.releaseUrl, 'package.release.releaseUrl'),
    @($model.package.artifacts.installer.url, 'package.artifacts.installer.url'),
    @($model.package.artifacts.installer.sha256, 'package.artifacts.installer.sha256'),
    @($model.package.artifacts.portable.url, 'package.artifacts.portable.url'),
    @($model.package.artifacts.portable.sha256, 'package.artifacts.portable.sha256'),
    @($model.package.clients.scoop.id, 'package.clients.scoop.id'),
    @($model.package.clients.winget.id, 'package.clients.winget.id'),
    @($model.package.clients.chocolatey.id, 'package.clients.chocolatey.id')
)) {
    Require-Value -Value $pair[0] -Name $pair[1]
}

Assert-Sha256 -Value ([string]$model.package.release.sourceSha) -Name 'package.release.sourceSha'
Assert-Sha256 -Value ([string]$model.package.artifacts.installer.sha256) -Name 'package.artifacts.installer.sha256'
Assert-Sha256 -Value ([string]$model.package.artifacts.portable.sha256) -Name 'package.artifacts.portable.sha256'

if ($model.package.state.provenance -ne 'approved' -or
    $model.package.state.lifecycle -ne 'approved' -or
    $model.package.state.promotion -ne 'approved') {
    throw 'Installable projection denied: provenance, lifecycle, and promotion must all be approved.'
}

if ($model.package.artifacts.installer.url -notmatch '^https://github\.com/[^/]+/[^/]+/releases/download/') {
    throw 'Installer URL must be an immutable GitHub Release download URL.'
}
if ($model.package.artifacts.portable.url -notmatch '^https://github\.com/[^/]+/[^/]+/releases/download/') {
    throw 'Portable URL must be an immutable GitHub Release download URL.'
}

$slug = [string]$model.package.slug
$version = [string]$model.package.release.version
$wingetId = [string]$model.package.clients.winget.id
$scoopId = [string]$model.package.clients.scoop.id
$chocoId = [string]$model.package.clients.chocolatey.id

$paths = @(
    'catalog/v1/packages',
    'bucket',
    "distribution/winget/$wingetId/$version",
    "chocolatey/packages/$chocoId/tools",
    "site/packages/$slug"
)
foreach ($relative in $paths) {
    New-Item -ItemType Directory -Force -Path (Join-Path $OutputRoot $relative) | Out-Null
}

# Canonical machine-readable package view.
$modelJson = $model | ConvertTo-Json -Depth 20
Set-Content -LiteralPath (Join-Path $OutputRoot "catalog/v1/packages/$slug.json") -Value $modelJson -Encoding utf8NoBOM

$catalog = [ordered]@{
    schemaVersion = 1
    packages = @(
        [ordered]@{
            slug = $slug
            id = [string]$model.package.identity.id
            name = [string]$model.package.identity.name
            version = $version
            state = [ordered]@{
                provenance = [string]$model.package.state.provenance
                lifecycle = [string]$model.package.state.lifecycle
                promotion = [string]$model.package.state.promotion
            }
            detail = "packages/$slug.json"
        }
    )
}
Set-Content -LiteralPath (Join-Path $OutputRoot 'catalog/v1/catalog.json') -Value ($catalog | ConvertTo-Json -Depth 10) -Encoding utf8NoBOM

# Scoop bucket: prefer the portable ZIP to avoid global installer side effects.
$bin = @($model.package.clients.scoop.bin)
$scoop = [ordered]@{
    version = $version
    description = [string]$model.package.identity.description
    homepage = [string]$model.package.identity.homepage
    license = [string]$model.package.identity.license
    architecture = [ordered]@{
        '64bit' = [ordered]@{
            url = [string]$model.package.artifacts.portable.url
            hash = [string]$model.package.artifacts.portable.sha256
        }
    }
    bin = $bin
}
Set-Content -LiteralPath (Join-Path $OutputRoot "bucket/$scoopId.json") -Value ($scoop | ConvertTo-Json -Depth 10) -Encoding utf8NoBOM

# WinGet local singleton manifest. Keep source explicit when/if a remote source exists later.
$manifestVersion = if ($model.package.clients.winget.manifestVersion) { [string]$model.package.clients.winget.manifestVersion } else { '1.12.0' }
$winget = @(
    "PackageIdentifier: $(Quote-Yaml ([string]$wingetId))",
    "PackageVersion: $(Quote-Yaml $version)",
    "PackageLocale: 'en-US'",
    "Publisher: $(Quote-Yaml ([string]$model.package.identity.publisher))",
    "PackageName: $(Quote-Yaml ([string]$model.package.identity.name))",
    "License: $(Quote-Yaml ([string]$model.package.identity.license))",
    "ShortDescription: $(Quote-Yaml ([string]$model.package.identity.description))",
    'Installers:',
    "- Architecture: $(Quote-Yaml ([string]$model.package.artifacts.installer.architecture))",
    "  InstallerType: $(Quote-Yaml ([string]$model.package.artifacts.installer.installerType))",
    "  InstallerUrl: $(Quote-Yaml ([string]$model.package.artifacts.installer.url))",
    "  InstallerSha256: $([string]$model.package.artifacts.installer.sha256)",
    "  Scope: $(Quote-Yaml ([string]$model.package.artifacts.installer.scope))",
    '  InstallerSwitches:',
    "    Silent: $(Quote-Yaml ([string]$model.package.artifacts.installer.silentArgs))",
    "    SilentWithProgress: $(Quote-Yaml ([string]$model.package.artifacts.installer.silentArgs))",
    "ManifestType: 'singleton'",
    "ManifestVersion: $manifestVersion"
) -join "`n"
Set-Content -LiteralPath (Join-Path $OutputRoot "distribution/winget/$wingetId/$version/$wingetId.yaml") -Value ($winget + "`n") -Encoding utf8NoBOM

# Chocolatey package source. choco pack produces the local-feed .nupkg.
$iconUrl = if ($model.package.clients.chocolatey.iconUrl) { [string]$model.package.clients.chocolatey.iconUrl } else { '' }
$nuspecLines = @(
    '<?xml version="1.0" encoding="utf-8"?>',
    '<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">',
    '  <metadata>',
    "    <id>$(Escape-Xml $chocoId)</id>",
    "    <version>$(Escape-Xml $version)</version>",
    "    <title>$(Escape-Xml ([string]$model.package.identity.name))</title>",
    "    <authors>$(Escape-Xml ([string]$model.package.identity.publisher))</authors>",
    "    <owners>$(Escape-Xml ([string]$model.package.identity.publisher))</owners>",
    "    <projectUrl>$(Escape-Xml ([string]$model.package.identity.homepage))</projectUrl>",
    "    <projectSourceUrl>$(Escape-Xml ([string]$model.package.release.sourceUrl))</projectSourceUrl>",
    "    <packageSourceUrl>$(Escape-Xml ([string]$model.package.clients.chocolatey.packageSourceUrl))</packageSourceUrl>",
    "    <licenseUrl>$(Escape-Xml ([string]$model.package.identity.licenseUrl))</licenseUrl>",
    $(if ($iconUrl) { "    <iconUrl>$(Escape-Xml $iconUrl)</iconUrl>" } else { $null }),
    "    <summary>$(Escape-Xml ([string]$model.package.identity.description))</summary>",
    "    <description>$(Escape-Xml ([string]$model.package.identity.description))</description>",
    "    <tags>$(Escape-Xml ([string]$model.package.clients.chocolatey.tags))</tags>",
    '  </metadata>',
    '  <files>',
    '    <file src="tools\**" target="tools" />',
    '  </files>',
    '</package>'
) | Where-Object { $null -ne $_ }
Set-Content -LiteralPath (Join-Path $OutputRoot "chocolatey/packages/$chocoId/$chocoId.nuspec") -Value (($nuspecLines -join "`n") + "`n") -Encoding utf8NoBOM

$installScript = @"
`$ErrorActionPreference = 'Stop'
`$packageArgs = @{
    packageName    = '$chocoId'
    fileType       = 'exe'
    url            = '$($model.package.artifacts.installer.url)'
    checksum       = '$($model.package.artifacts.installer.sha256)'
    checksumType   = 'sha256'
    silentArgs     = '$($model.package.artifacts.installer.silentArgs)'
    validExitCodes = @(0)
}
Install-ChocolateyPackage @packageArgs
"@
Set-Content -LiteralPath (Join-Path $OutputRoot "chocolatey/packages/$chocoId/tools/chocolateyInstall.ps1") -Value $installScript -Encoding utf8NoBOM

# Static HTML is a rendering of the same model, not authority.
$name = Escape-Html ([string]$model.package.identity.name)
$description = Escape-Html ([string]$model.package.identity.description)
$sourceSha = Escape-Html ([string]$model.package.release.sourceSha)
$installerSha = Escape-Html ([string]$model.package.artifacts.installer.sha256)
$releaseUrl = Escape-Html ([string]$model.package.release.releaseUrl)
$scoopCommand = "scoop install semper-supra/$scoopId"
$wingetCommand = "winget install --manifest <foundry>/distribution/winget/$wingetId/$version"
$chocoCommand = "choco install $chocoId --source <foundry>/chocolatey/feed"
$html = @"
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$name $version - Windows Package Foundry</title></head>
<body>
<main>
<h1>$name <small>$version</small></h1>
<p>$description</p>
<dl>
<dt>Provenance</dt><dd>approved</dd>
<dt>Lifecycle</dt><dd>approved</dd>
<dt>Promotion</dt><dd>approved</dd>
<dt>Source SHA</dt><dd><code>$sourceSha</code></dd>
<dt>Installer SHA-256</dt><dd><code>$installerSha</code></dd>
</dl>
<h2>Install</h2>
<h3>Scoop</h3><pre><code>$(Escape-Html $scoopCommand)</code></pre>
<h3>WinGet local manifest</h3><pre><code>$(Escape-Html $wingetCommand)</code></pre>
<h3>Chocolatey local feed</h3><pre><code>$(Escape-Html $chocoCommand)</code></pre>
<p><a href="$releaseUrl">Immutable product release</a></p>
<p>This page is generated convenience data. Verify the release evidence and hashes before relying on it for high-assurance use.</p>
</main>
</body>
</html>
"@
Set-Content -LiteralPath (Join-Path $OutputRoot "site/packages/$slug/index.html") -Value $html -Encoding utf8NoBOM

Write-Host "Generated public package projection for $($model.package.identity.id) $version."
