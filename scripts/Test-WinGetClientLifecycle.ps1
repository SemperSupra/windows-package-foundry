#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $InstallerUrl,

    [Parameter(Mandatory)]
    [string] $InstallerSha256,

    [Parameter(Mandatory)]
    [string] $PackageIdentifier,

    [Parameter(Mandatory)]
    [string] $PackageVersion,

    [Parameter(Mandatory)]
    [string] $Publisher,

    [Parameter(Mandatory)]
    [string] $PackageName,

    [Parameter(Mandatory)]
    [string] $License,

    [Parameter(Mandatory)]
    [string] $Description,

    [string] $ExpectedInstallDirectory = (Join-Path $env:LOCALAPPDATA 'WinInspect'),
    [string] $UninstallKeyName = 'WinInspect',
    [string[]] $ExpectedExecutables = @('wininspectd.exe', 'wininspect.exe', 'wininspect-gui.exe'),
    [string] $EvidencePath = (Join-Path $PWD 'client-lifecycle-evidence.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Assert-ExitCode {
    param([System.Diagnostics.Process] $Process, [string] $Operation)
    if ($Process.ExitCode -ne 0) {
        throw "$Operation failed with exit code $($Process.ExitCode)."
    }
}

function Assert-InstalledState {
    param([string] $Stage)

    if (-not (Test-Path -LiteralPath $ExpectedInstallDirectory -PathType Container)) {
        throw "${Stage}: expected install directory is absent: $ExpectedInstallDirectory"
    }

    foreach ($exe in $ExpectedExecutables) {
        $path = Join-Path $ExpectedInstallDirectory $exe
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "${Stage}: expected executable is absent: $path"
        }
    }

    $hkcu = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName"
    if (-not (Test-Path -LiteralPath $hkcu)) {
        throw "${Stage}: expected HKCU uninstall registration is absent: $hkcu"
    }

    $hklmPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName"
    )
    foreach ($path in $hklmPaths) {
        if (Test-Path -LiteralPath $path) {
            throw "${Stage}: unexpected machine-scope uninstall registration exists: $path"
        }
    }
}

function Assert-UninstalledState {
    if (Test-Path -LiteralPath $ExpectedInstallDirectory) {
        throw "Uninstall left the install directory behind: $ExpectedInstallDirectory"
    }

    foreach ($path in @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName"
    )) {
        if (Test-Path -LiteralPath $path) {
            throw "Uninstall left registration behind: $path"
        }
    }
}

if ($InstallerSha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'InstallerSha256 must be a 64-character SHA-256 value.'
}
if ($InstallerUrl -notmatch '^https://github\.com/[^/]+/[^/]+/releases/download/') {
    throw 'InstallerUrl must be an immutable GitHub Release download URL.'
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('foundry-winget-lifecycle-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

try {
    $installerPath = Join-Path $work 'installer.exe'
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerPath -UseBasicParsing
    $actualHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $InstallerSha256.ToLowerInvariant()) {
        throw "Downloaded installer SHA-256 mismatch. Expected $InstallerSha256, got $actualHash."
    }

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers | Out-Null
        Import-Module Microsoft.WinGet.Client
        Repair-WinGetPackageManager -AllUsers
    }

    $winget = Get-Command winget.exe -ErrorAction Stop
    Write-Host "Using WinGet: $($winget.Source)"
    & $winget.Source settings --enable LocalManifestFiles
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to enable WinGet LocalManifestFiles; exit code $LASTEXITCODE."
    }

    $manifestPath = Join-Path $work 'manifest.yaml'
    function YamlQuote([string] $Value) { return "'" + $Value.Replace("'", "''") + "'" }
    $manifest = @(
        "PackageIdentifier: $(YamlQuote $PackageIdentifier)",
        "PackageVersion: $(YamlQuote $PackageVersion)",
        "PackageLocale: 'en-US'",
        "Publisher: $(YamlQuote $Publisher)",
        "PackageName: $(YamlQuote $PackageName)",
        "License: $(YamlQuote $License)",
        "ShortDescription: $(YamlQuote $Description)",
        'Installers:',
        "- Architecture: 'x64'",
        "  InstallerType: 'nullsoft'",
        "  InstallerUrl: $(YamlQuote $InstallerUrl)",
        "  InstallerSha256: $InstallerSha256",
        "  Scope: 'user'",
        '  InstallerSwitches:',
        "    Silent: '/S'",
        "    SilentWithProgress: '/S'",
        "ManifestType: 'singleton'",
        'ManifestVersion: 1.12.0'
    ) -join "`n"
    Set-Content -LiteralPath $manifestPath -Value ($manifest + "`n") -Encoding utf8NoBOM

    & $winget.Source validate --manifest $manifestPath --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "winget validate failed with exit code $LASTEXITCODE."
    }

    & $winget.Source install --manifest $manifestPath --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "winget install --manifest failed with exit code $LASTEXITCODE."
    }
    Assert-InstalledState -Stage 'WinGet install'

    $repeat = Start-Process -FilePath $installerPath -ArgumentList '/S' -Wait -PassThru
    Assert-ExitCode -Process $repeat -Operation 'Repeat silent install'
    Assert-InstalledState -Stage 'Repeat install'

    & $winget.Source uninstall --name $PackageName --exact --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "winget uninstall failed with exit code $LASTEXITCODE."
    }
    Assert-UninstalledState

    $evidence = [ordered]@{
        schemaVersion = 1
        packageIdentifier = $PackageIdentifier
        packageVersion = $PackageVersion
        installerUrl = $InstallerUrl
        installerSha256 = $InstallerSha256.ToLowerInvariant()
        runner = [ordered]@{
            os = [System.Environment]::OSVersion.VersionString
            wingetVersion = (& $winget.Source --version | Select-Object -First 1)
        }
        checks = [ordered]@{
            hashVerified = $true
            manifestValidated = $true
            wingetInstall = 'passed'
            userScopeRegistration = 'passed'
            machineScopeRegistrationAbsent = 'passed'
            repeatSilentInstall = 'passed'
            wingetUninstall = 'passed'
            completeCleanup = 'passed'
        }
        verdict = 'passed'
    }
    $evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $EvidencePath -Encoding utf8NoBOM
    Write-Host "WinGet client lifecycle proof passed; evidence: $EvidencePath"
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
