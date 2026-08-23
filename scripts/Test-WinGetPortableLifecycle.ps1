#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PortableUrl,
    [Parameter(Mandatory)][string] $PortableSha256,
    [Parameter(Mandatory)][string] $PackageIdentifier,
    [Parameter(Mandatory)][string] $PackageVersion,
    [Parameter(Mandatory)][string] $Publisher,
    [Parameter(Mandatory)][string] $PackageName,
    [Parameter(Mandatory)][string] $License,
    [Parameter(Mandatory)][string] $Description,
    [string] $EvidencePath = (Join-Path $PWD 'winget-portable-lifecycle-evidence.json'),
    [int] $OperationTimeoutSeconds = 90,
    [int] $CleanupTimeoutSeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($PortableSha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'PortableSha256 must be a 64-character SHA-256 value.' }
if ($PortableUrl -notmatch '^https://github\.com/[^/]+/[^/]+/releases/download/') { throw 'PortableUrl must be an immutable GitHub Release download URL.' }
if ($OperationTimeoutSeconds -lt 30 -or $OperationTimeoutSeconds -gt 600) { throw 'OperationTimeoutSeconds must be between 30 and 600 seconds.' }
if ($CleanupTimeoutSeconds -lt 1 -or $CleanupTimeoutSeconds -gt 60) { throw 'CleanupTimeoutSeconds must be between 1 and 60 seconds.' }

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('foundry-winget-portable-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$linksRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
$aliases = @('wininspect.exe', 'wininspectd.exe', 'wininspect-gui.exe')

function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [Parameter(Mandatory)][string[]] $Arguments,
        [Parameter(Mandatory)][string] $Operation,
        [int] $TimeoutSeconds = $OperationTimeoutSeconds
    )

    $safeName = ($Operation -replace '[^A-Za-z0-9_.-]', '-')
    $stdoutPath = Join-Path $work "$safeName.stdout.log"
    $stderrPath = Join-Path $work "$safeName.stderr.log"
    Write-Host "BEGIN $Operation"
    Write-Host "Executable: $FilePath"
    Write-Host "Arguments: $($Arguments -join ' ')"

    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Write-Host "$Operation exceeded ${TimeoutSeconds}s; terminating process tree PID $($process.Id)."
        try { & taskkill.exe /PID $process.Id /T /F | Write-Host } catch { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath | Write-Host }
        if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath | Write-Host }
        throw "$Operation timed out after ${TimeoutSeconds}s."
    }
    $process.WaitForExit()
    if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath | Write-Host }
    if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath | Write-Host }
    Write-Host "END $Operation (exit $($process.ExitCode))"
    if ($process.ExitCode -ne 0) { throw "$Operation failed with exit code $($process.ExitCode)." }
}

function Assert-PortableInstalled {
    foreach ($alias in $aliases) {
        $path = Join-Path $linksRoot $alias
        if (-not (Test-Path -LiteralPath $path)) { throw "Expected WinGet portable alias is absent: $path" }
    }
}

function Wait-PortableRemoved {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $CleanupTimeoutSeconds) {
        $remaining = @($aliases | Where-Object { Test-Path -LiteralPath (Join-Path $linksRoot $_) })
        if ($remaining.Count -eq 0) {
            $sw.Stop()
            Write-Host ("Portable uninstall converged after {0:N3}s." -f $sw.Elapsed.TotalSeconds)
            return $sw.Elapsed.TotalMilliseconds
        }
        Start-Sleep -Milliseconds 200
    }
    $sw.Stop()
    throw "Portable aliases remained after uninstall: $($remaining -join ', ')"
}

function YamlQuote([string] $Value) { return "'" + $Value.Replace("'", "''") + "'" }

try {
    $archive = Join-Path $work 'WinInspectPortable.zip'
    Invoke-WebRequest -Uri $PortableUrl -OutFile $archive -UseBasicParsing
    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $PortableSha256.ToLowerInvariant()) {
        throw "Portable archive SHA-256 mismatch. Expected $PortableSha256, got $actualHash."
    }

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers | Out-Null
        Import-Module Microsoft.WinGet.Client
        Repair-WinGetPackageManager -AllUsers
    }
    $winget = Get-Command winget.exe -ErrorAction Stop
    $wingetVersion = (& $winget.Source --version | Select-Object -First 1)
    Write-Host "Using WinGet $wingetVersion at $($winget.Source)"

    Invoke-BoundedProcess -FilePath $winget.Source -Operation 'winget-settings-enable-local-manifests' -Arguments @('settings','--enable','LocalManifestFiles') -TimeoutSeconds 60

    $manifestVersion = '1.10.0'
    $manifestPath = Join-Path $work 'manifest.yaml'
    $manifest = @(
        "# yaml-language-server: `$schema=https://aka.ms/winget-manifest.singleton.$manifestVersion.schema.json",
        '',
        "PackageIdentifier: $(YamlQuote $PackageIdentifier)",
        "PackageVersion: $(YamlQuote $PackageVersion)",
        "PackageLocale: 'en-US'",
        "Publisher: $(YamlQuote $Publisher)",
        "PackageName: $(YamlQuote $PackageName)",
        "License: $(YamlQuote $License)",
        "ShortDescription: $(YamlQuote $Description)",
        "InstallerType: 'zip'",
        "NestedInstallerType: 'portable'",
        'NestedInstallerFiles:',
        "- RelativeFilePath: 'App\WinInspect\wininspect.exe'",
        "  PortableCommandAlias: 'wininspect'",
        "- RelativeFilePath: 'App\WinInspect\wininspectd.exe'",
        "  PortableCommandAlias: 'wininspectd'",
        "- RelativeFilePath: 'App\WinInspect\wininspect-gui.exe'",
        "  PortableCommandAlias: 'wininspect-gui'",
        'Installers:',
        "- Architecture: 'x64'",
        "  InstallerUrl: $(YamlQuote $PortableUrl)",
        "  InstallerSha256: $PortableSha256",
        "ManifestType: 'singleton'",
        "ManifestVersion: $manifestVersion"
    ) -join "`n"
    Set-Content -LiteralPath $manifestPath -Value ($manifest + "`n") -Encoding utf8NoBOM

    Invoke-BoundedProcess -FilePath $winget.Source -Operation 'winget-validate-portable' -Arguments @('validate','--manifest',$manifestPath,'--disable-interactivity')
    Invoke-BoundedProcess -FilePath $winget.Source -Operation 'winget-install-portable' -Arguments @('install','--manifest',$manifestPath,'--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
    Assert-PortableInstalled

    Invoke-BoundedProcess -FilePath $winget.Source -Operation 'winget-repeat-install-portable' -Arguments @('install','--manifest',$manifestPath,'--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
    Assert-PortableInstalled

    Invoke-BoundedProcess -FilePath $winget.Source -Operation 'winget-uninstall-portable' -Arguments @('uninstall','--id',$PackageIdentifier,'--exact','--accept-source-agreements','--disable-interactivity')
    $cleanupMs = Wait-PortableRemoved

    $evidence = [ordered]@{
        schemaVersion = 1
        packageIdentifier = $PackageIdentifier
        packageVersion = $PackageVersion
        artifactType = 'portable-zip'
        portableUrl = $PortableUrl
        portableSha256 = $PortableSha256.ToLowerInvariant()
        manifestVersion = $manifestVersion
        runner = [ordered]@{
            os = [System.Environment]::OSVersion.VersionString
            wingetVersion = $wingetVersion
        }
        checks = [ordered]@{
            hashVerified = $true
            manifestValidated = $true
            wingetInstall = 'passed'
            aliasesPresent = @($aliases)
            repeatInstall = 'passed'
            wingetUninstall = 'passed'
            aliasesRemoved = 'passed'
        }
        cleanupConvergenceMilliseconds = [math]::Round($cleanupMs, 1)
        verdict = 'passed'
    }
    $evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $EvidencePath -Encoding utf8NoBOM
    Write-Host "WinGet portable lifecycle proof passed; evidence: $EvidencePath"
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
