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
    [string] $EvidencePath = (Join-Path $PWD 'client-lifecycle-evidence.json'),
    [string] $FailureEvidencePath = (Join-Path $PWD 'client-lifecycle-timeout.json'),
    [int] $OperationTimeoutSeconds = 90,
    [int] $CleanupTimeoutSeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('foundry-winget-lifecycle-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Get-InstallState {
    $hkcu = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName"
    $hklm = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName"
    $hklmWow = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName"

    [ordered]@{
        installDirectoryPresent = Test-Path -LiteralPath $ExpectedInstallDirectory -PathType Container
        files = if (Test-Path -LiteralPath $ExpectedInstallDirectory -PathType Container) {
            @(Get-ChildItem -LiteralPath $ExpectedInstallDirectory -Force -ErrorAction SilentlyContinue |
                Select-Object Name, Length, LastWriteTimeUtc)
        } else { @() }
        hkcuUninstallPresent = Test-Path -LiteralPath $hkcu
        hklmUninstallPresent = Test-Path -LiteralPath $hklm
        hklmWowUninstallPresent = Test-Path -LiteralPath $hklmWow
    }
}

function Save-LiveProcessSnapshot {
    param(
        [Parameter(Mandatory)][int] $RootProcessId,
        [Parameter(Mandatory)][string] $Operation
    )

    $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    $ids = [System.Collections.Generic.HashSet[int]]::new()
    [void]$ids.Add($RootProcessId)

    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($proc in $all) {
            if ($ids.Contains([int]$proc.ParentProcessId) -and -not $ids.Contains([int]$proc.ProcessId)) {
                [void]$ids.Add([int]$proc.ProcessId)
                $changed = $true
            }
        }
    }

    $tree = @($all | Where-Object { $ids.Contains([int]$_.ProcessId) } |
        Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine)
    $related = @($all | Where-Object {
        $_.CommandLine -match 'WinInspect|SemperSupra|winget|vc_redist|~ns' -or
        $_.Name -match '^(winget|WinInspect|vc_redist|installer|uninstall|Un\.exe)'
    } | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine)
    $windows = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowHandle -ne 0 -and ($ids.Contains([int]$_.Id) -or $_.ProcessName -match 'winget|WinInspect|vc_redist|installer|uninstall|^Un$')
    } | Select-Object Id, ProcessName, MainWindowTitle, Responding)

    $snapshot = [ordered]@{
        schemaVersion = 1
        capturedAtUtc = [DateTime]::UtcNow.ToString('o')
        operation = $Operation
        rootProcessId = $RootProcessId
        processTree = $tree
        relatedProcesses = $related
        visibleWindows = $windows
        installState = Get-InstallState
    }
    $snapshot | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $FailureEvidencePath -Encoding utf8NoBOM
    $snapshot | ConvertTo-Json -Depth 10 | Write-Host
}

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

    $process = Start-Process -FilePath $FilePath `
        -ArgumentList $Arguments `
        -PassThru `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath

    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
        Write-Host "$Operation exceeded ${TimeoutSeconds}s; capturing live process tree before termination."
        Save-LiveProcessSnapshot -RootProcessId $process.Id -Operation $Operation
        try {
            & taskkill.exe /PID $process.Id /T /F | Write-Host
        } catch {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        } finally {
            if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath | Write-Host }
            if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath | Write-Host }
        }
        throw "$Operation timed out after ${TimeoutSeconds}s."
    }

    $process.WaitForExit()
    if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath | Write-Host }
    if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath | Write-Host }

    Write-Host "END $Operation (exit $($process.ExitCode))"
    if ($process.ExitCode -ne 0) {
        throw "$Operation failed with exit code $($process.ExitCode)."
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

    foreach ($path in @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName"
    )) {
        if (Test-Path -LiteralPath $path) {
            throw "${Stage}: unexpected machine-scope uninstall registration exists: $path"
        }
    }

    Write-Host "$Stage state validation passed."
}

function Wait-ForUninstalledState {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $lastState = $null
    while ($stopwatch.Elapsed.TotalSeconds -lt $CleanupTimeoutSeconds) {
        $lastState = Get-InstallState
        $clean = -not $lastState.installDirectoryPresent -and
            -not $lastState.hkcuUninstallPresent -and
            -not $lastState.hklmUninstallPresent -and
            -not $lastState.hklmWowUninstallPresent
        if ($clean) {
            $stopwatch.Stop()
            Write-Host ("Uninstall converged to clean state after {0:N3}s." -f $stopwatch.Elapsed.TotalSeconds)
            return $stopwatch.Elapsed.TotalMilliseconds
        }
        Start-Sleep -Milliseconds 200
    }

    $stopwatch.Stop()
    throw "Uninstall did not converge to clean state within ${CleanupTimeoutSeconds}s. Last state: $($lastState | ConvertTo-Json -Compress -Depth 5)"
}

if ($OperationTimeoutSeconds -lt 30 -or $OperationTimeoutSeconds -gt 600) {
    throw 'OperationTimeoutSeconds must be between 30 and 600 seconds.'
}
if ($CleanupTimeoutSeconds -lt 1 -or $CleanupTimeoutSeconds -gt 60) {
    throw 'CleanupTimeoutSeconds must be between 1 and 60 seconds.'
}
if ($InstallerSha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'InstallerSha256 must be a 64-character SHA-256 value.'
}
if ($InstallerUrl -notmatch '^https://github\.com/[^/]+/[^/]+/releases/download/') {
    throw 'InstallerUrl must be an immutable GitHub Release download URL.'
}

try {
    Write-Host 'BEGIN download/hash verification'
    $installerPath = Join-Path $work 'installer.exe'
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerPath -UseBasicParsing
    $actualHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $InstallerSha256.ToLowerInvariant()) {
        throw "Downloaded installer SHA-256 mismatch. Expected $InstallerSha256, got $actualHash."
    }
    Write-Host 'END download/hash verification (passed)'

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Host 'WinGet is absent; using Microsoft.WinGet.Client repair/bootstrap path.'
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers | Out-Null
        Import-Module Microsoft.WinGet.Client
        Repair-WinGetPackageManager -AllUsers
    }

    $winget = Get-Command winget.exe -ErrorAction Stop
    $wingetVersion = (& $winget.Source --version | Select-Object -First 1)
    Write-Host "Using WinGet $wingetVersion at $($winget.Source)"

    Invoke-BoundedProcess -FilePath $winget.Source -Operation 'winget-settings-enable-local-manifests' -Arguments @(
        'settings', '--enable', 'LocalManifestFiles'
    ) -TimeoutSeconds 60

    # 1.10.0 is the MVP compatibility floor: all fields used here are available
    # in it, and newer clients remain able to consume the older frozen schema.
    $manifestVersion = '1.10.0'
    $manifestPath = Join-Path $work 'manifest.yaml'
    function YamlQuote([string] $Value) { return "'" + $Value.Replace("'", "''") + "'" }
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
        "ManifestVersion: $manifestVersion"
    ) -join "`n"
    Set-Content -LiteralPath $manifestPath -Value ($manifest + "`n") -Encoding utf8NoBOM

    Invoke-BoundedProcess -FilePath $winget.Source -Operation 'winget-validate' -Arguments @(
        'validate', '--manifest', $manifestPath, '--disable-interactivity'
    ) -TimeoutSeconds 90

    Invoke-BoundedProcess -FilePath $winget.Source -Operation 'winget-install' -Arguments @(
        'install', '--manifest', $manifestPath,
        '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
    )
    Assert-InstalledState -Stage 'WinGet install'

    Invoke-BoundedProcess -FilePath $installerPath -Operation 'repeat-silent-install' -Arguments @('/S')
    Assert-InstalledState -Stage 'Repeat install'

    Invoke-BoundedProcess -FilePath $winget.Source -Operation 'winget-uninstall' -Arguments @(
        'uninstall', '--name', $PackageName, '--exact', '--disable-interactivity'
    )
    $cleanupMs = Wait-ForUninstalledState

    $evidence = [ordered]@{
        schemaVersion = 1
        packageIdentifier = $PackageIdentifier
        packageVersion = $PackageVersion
        installerUrl = $InstallerUrl
        installerSha256 = $InstallerSha256.ToLowerInvariant()
        manifestVersion = $manifestVersion
        runner = [ordered]@{
            os = [System.Environment]::OSVersion.VersionString
            wingetVersion = $wingetVersion
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
        cleanupConvergenceMilliseconds = [math]::Round($cleanupMs, 1)
        verdict = 'passed'
    }
    $evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $EvidencePath -Encoding utf8NoBOM
    Write-Host "WinGet client lifecycle proof passed; evidence: $EvidencePath"
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
