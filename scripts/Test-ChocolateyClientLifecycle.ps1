#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $InstallerUrl,
    [Parameter(Mandatory)][string] $InstallerSha256,
    [Parameter(Mandatory)][string] $PackageId,
    [Parameter(Mandatory)][string] $PackageVersion,
    [string] $InstallDirectory = (Join-Path $env:LOCALAPPDATA 'WinInspect'),
    [string[]] $ExpectedExecutables = @('wininspectd.exe', 'wininspect.exe', 'wininspect-gui.exe'),
    [string] $EvidencePath = (Join-Path $PWD 'chocolatey-lifecycle-evidence.json'),
    [int] $CleanupTimeoutSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($InstallerSha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'InstallerSha256 must be a 64-character SHA-256 value.' }
if ($InstallerUrl -notmatch '^https://github\.com/[^/]+/[^/]+/releases/download/') { throw 'InstallerUrl must be an immutable GitHub Release download URL.' }
if ($PackageVersion -notmatch '^\d+\.\d+\.\d+([.-][0-9A-Za-z.-]+)?$') { throw 'PackageVersion is not a supported package version.' }

$managedSilentArgs = '/S /MANAGED-BY=chocolatey'
$directSilentArgs = '/S'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('foundry-chocolatey-' + [guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $work 'package'
$tools = Join-Path $packageRoot 'tools'
$feed = Join-Path $work 'feed'
$installerProbe = Join-Path $work 'WinInspect-installer-probe.exe'
New-Item -ItemType Directory -Force -Path $tools, $feed | Out-Null

function Invoke-Choco {
    param([Parameter(Mandatory)][string[]] $Arguments, [Parameter(Mandatory)][string] $Operation)
    Write-Host "BEGIN $Operation"
    Write-Host "choco $($Arguments -join ' ')"
    & choco.exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        if (Test-Path 'C:\ProgramData\chocolatey\logs\chocolatey.log') {
            Write-Host "--- Last 100 lines of chocolatey.log ---"
            Get-Content 'C:\ProgramData\chocolatey\logs\chocolatey.log' -Tail 100 | Out-Host
        }
        throw "$Operation failed with exit code $LASTEXITCODE."
    }
    Write-Host "END $Operation"
}

function Assert-Installed {
    if (-not (Test-Path -LiteralPath $InstallDirectory -PathType Container)) { throw "Expected install directory is absent: $InstallDirectory" }
    foreach ($exe in $ExpectedExecutables) {
        $path = Join-Path $InstallDirectory $exe
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Expected installed executable is absent: $path" }
    }
    $hkcu = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WinInspect'
    if (-not (Test-Path -LiteralPath $hkcu)) { throw "Expected WinInspect HKCU uninstall registration is absent: $hkcu" }
    foreach ($machineKey in @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WinInspect',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\WinInspect'
    )) {
        if (Test-Path -LiteralPath $machineKey) { throw "Unexpected machine-scope WinInspect registration exists: $machineKey" }
    }
}

function Wait-Uninstalled {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $CleanupTimeoutSeconds) {
        $remaining = @()
        if (Test-Path -LiteralPath $InstallDirectory) { $remaining += $InstallDirectory }
        foreach ($key in @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WinInspect',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WinInspect',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\WinInspect'
        )) {
            if (Test-Path -LiteralPath $key) { $remaining += $key }
        }
        if ($remaining.Count -eq 0) {
            $sw.Stop()
            return $sw.Elapsed.TotalMilliseconds
        }
        Start-Sleep -Milliseconds 200
    }
    throw "Chocolatey uninstall did not converge; remaining: $($remaining -join ', ')"
}

try {
    $choco = Get-Command choco.exe -ErrorAction Stop
    $chocoVersion = (& $choco.Source --version | Select-Object -First 1).Trim()
    Write-Host "Using Chocolatey $chocoVersion at $($choco.Source)"

    # Keep an independently hash-verified copy so we can prove that a direct
    # silent NSIS invocation cannot cross a Chocolatey-owned installation
    # boundary without the explicit package-manager handoff switch.
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerProbe
    $probeHash = (Get-FileHash -LiteralPath $installerProbe -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($probeHash -ne $InstallerSha256.ToLowerInvariant()) {
        throw "Downloaded installer probe hash mismatch: expected $InstallerSha256, observed $probeHash"
    }

    $nuspec = @"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
  <metadata>
    <id>$PackageId</id>
    <version>$PackageVersion</version>
    <title>WinInspect</title>
    <authors>Mark E. DeYoung</authors>
    <owners>Mark E. DeYoung</owners>
    <projectUrl>https://github.com/SemperSupra/WinInspect</projectUrl>
    <packageSourceUrl>https://github.com/SemperSupra/windows-package-foundry</packageSourceUrl>
    <licenseUrl>https://github.com/SemperSupra/WinInspect/blob/v$PackageVersion/LICENSE</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <description>Window inspection and automation tool for Windows and Wine.</description>
    <tags>windows automation inspection screen-capture wine</tags>
  </metadata>
  <files>
    <file src="tools\**" target="tools" />
  </files>
</package>
"@
    Set-Content -LiteralPath (Join-Path $packageRoot "$PackageId.nuspec") -Value $nuspec -Encoding utf8NoBOM

    $install = @"
`$ErrorActionPreference = 'Stop'
try { [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls12,Tls13' } catch {}
`$packageArgs = @{
    packageName    = '$PackageId'
    fileType       = 'exe'
    url            = '$InstallerUrl'
    url64bit       = '$InstallerUrl'
    checksum       = '$($InstallerSha256.ToLowerInvariant())'
    checksumType   = 'sha256'
    checksum64     = '$($InstallerSha256.ToLowerInvariant())'
    checksumType64 = 'sha256'
    silentArgs     = '$managedSilentArgs'
    validExitCodes = @(0, 3010)
}
Install-ChocolateyPackage @packageArgs
"@
    Set-Content -LiteralPath (Join-Path $tools 'chocolateyInstall.ps1') -Value $install -Encoding utf8NoBOM

    $uninstall = @"
`$ErrorActionPreference = 'Stop'
`$uninstaller = Join-Path `$env:LOCALAPPDATA 'WinInspect\uninstall.exe'
if (Test-Path -LiteralPath `$uninstaller -PathType Leaf) {
    `$process = Start-Process -FilePath `$uninstaller -ArgumentList '/S' -PassThru -Wait
    if (`$process.ExitCode -ne 0) { throw "WinInspect uninstaller failed with exit code `$(`$process.ExitCode)." }
}
"@
    Set-Content -LiteralPath (Join-Path $tools 'chocolateyUninstall.ps1') -Value $uninstall -Encoding utf8NoBOM

    Invoke-Choco -Operation 'choco-pack' -Arguments @('pack', (Join-Path $packageRoot "$PackageId.nuspec"), '--output-directory', $feed, '--limit-output')
    $nupkg = Get-ChildItem -LiteralPath $feed -Filter "$PackageId.$PackageVersion.nupkg" -File | Select-Object -First 1
    if (-not $nupkg) { throw 'Chocolatey pack did not create the expected nupkg.' }
    $nupkgHash = (Get-FileHash -LiteralPath $nupkg.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

    Invoke-Choco -Operation 'choco-install-local-feed' -Arguments @('install', $PackageId, '--version', $PackageVersion, '--source', $feed, '--yes', '--no-progress', '--verbose')
    Assert-Installed

    # The Chocolatey package is now the owner. A bare direct silent installer
    # must fail closed; only Chocolatey's explicit /MANAGED-BY=chocolatey
    # invocation is authorized to install/update while that ownership exists.
    $directProcess = Start-Process -FilePath $installerProbe -ArgumentList $directSilentArgs -PassThru -Wait
    if ($directProcess.ExitCode -eq 0) {
        throw 'Direct silent NSIS invocation crossed a Chocolatey-owned installation boundary without explicit package-manager authorization.'
    }
    Assert-Installed

    Invoke-Choco -Operation 'choco-repeat-install' -Arguments @('install', $PackageId, '--version', $PackageVersion, '--source', $feed, '--yes', '--no-progress', '--verbose', '--force')
    Assert-Installed

    Invoke-Choco -Operation 'choco-uninstall' -Arguments @('uninstall', $PackageId, '--yes', '--no-progress', '--verbose')
    $cleanupMs = Wait-Uninstalled

    $localList = & choco.exe list --local-only --exact $PackageId --limit-output
    if ($LASTEXITCODE -ne 0) { throw "choco list failed with exit code $LASTEXITCODE." }
    if (($localList -join "`n") -match "(?im)^$([regex]::Escape($PackageId))\|") { throw 'Chocolatey package metadata remained installed after uninstall.' }

    $evidence = [ordered]@{
        schemaVersion = 1
        client = 'chocolatey'
        packageId = $PackageId
        packageVersion = $PackageVersion
        artifactType = 'nsis-installer'
        installerUrl = $InstallerUrl
        installerSha256 = $InstallerSha256.ToLowerInvariant()
        chocolateyVersion = $chocoVersion
        generatedNupkgSha256 = $nupkgHash
        managedInstallerArgs = $managedSilentArgs
        checks = [ordered]@{
            localFeedPacked = 'passed'
            install = 'passed'
            userScopeRegistration = 'passed'
            machineScopeRegistrationAbsent = 'passed'
            directSilentOwnershipBoundaryRejected = 'passed'
            repeatInstall = 'passed'
            uninstall = 'passed'
            cleanup = 'passed'
            packageMetadataRemoved = 'passed'
        }
        cleanupConvergenceMilliseconds = [math]::Round($cleanupMs, 1)
        verdict = 'passed'
    }
    $evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $EvidencePath -Encoding utf8NoBOM
    Write-Host "Chocolatey lifecycle proof passed; evidence: $EvidencePath"
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
