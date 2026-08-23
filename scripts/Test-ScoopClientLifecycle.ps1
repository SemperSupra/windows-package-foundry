#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PortableUrl,
    [Parameter(Mandatory)][string] $PortableSha256,
    [Parameter(Mandatory)][string] $PackageId,
    [Parameter(Mandatory)][string] $PackageVersion,
    [Parameter(Mandatory)][string[]] $Bin,
    [string] $EvidencePath = (Join-Path $PWD 'scoop-lifecycle-evidence.json'),
    [string] $ScoopInstallerCommit = '3bcaeb2ea53ad611fd8552eb9f735c5e2cd52f40',
    [int] $CleanupTimeoutSeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($PortableSha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'PortableSha256 must be a 64-character SHA-256 value.' }
if ($PortableUrl -notmatch '^https://github\.com/[^/]+/[^/]+/releases/download/') { throw 'PortableUrl must be an immutable GitHub Release download URL.' }
if ($ScoopInstallerCommit -notmatch '^[0-9a-fA-F]{40}$') { throw 'ScoopInstallerCommit must be a 40-character Git commit SHA.' }
if ($Bin.Count -eq 0) { throw 'At least one archive-relative bin path is required.' }

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('foundry-scoop-' + [guid]::NewGuid().ToString('N'))
$scoopRoot = Join-Path $work 'scoop'
$bucketRoot = Join-Path $work 'bucket-repo'
$bucketDir = Join-Path $bucketRoot 'bucket'
New-Item -ItemType Directory -Force -Path $bucketDir | Out-Null

function Invoke-Checked {
    param([Parameter(Mandatory)][string] $FilePath, [Parameter(Mandatory)][string[]] $Arguments, [Parameter(Mandatory)][string] $Operation)
    Write-Host "BEGIN $Operation"
    Write-Host "Executable: $FilePath"
    Write-Host "Arguments: $($Arguments -join ' ')"
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE." }
    Write-Host "END $Operation"
}

function Wait-Removed {
    param([string[]] $Paths)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $CleanupTimeoutSeconds) {
        $remaining = @($Paths | Where-Object { Test-Path -LiteralPath $_ })
        if ($remaining.Count -eq 0) {
            $sw.Stop()
            return $sw.Elapsed.TotalMilliseconds
        }
        Start-Sleep -Milliseconds 200
    }
    throw "Scoop cleanup did not converge; remaining: $($remaining -join ', ')"
}

try {
    $archive = Join-Path $work 'WinInspectPortable.zip'
    Invoke-WebRequest -Uri $PortableUrl -OutFile $archive -UseBasicParsing
    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $PortableSha256.ToLowerInvariant()) {
        throw "Portable archive SHA-256 mismatch. Expected $PortableSha256, got $actualHash."
    }

    $installerUrl = "https://raw.githubusercontent.com/ScoopInstaller/Install/$ScoopInstallerCommit/install.ps1"
    $installerPath = Join-Path $work 'install-scoop.ps1'
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    & $installerPath -ScoopDir $scoopRoot
    if ($LASTEXITCODE -ne 0) { throw "Pinned Scoop installer failed with exit code $LASTEXITCODE." }

    $scoop = Join-Path $scoopRoot 'shims\scoop.ps1'
    if (-not (Test-Path -LiteralPath $scoop -PathType Leaf)) { throw "Scoop shim was not installed: $scoop" }

    $manifest = [ordered]@{
        version = $PackageVersion
        description = 'WinInspect Foundry lifecycle candidate.'
        homepage = 'https://github.com/SemperSupra/WinInspect'
        license = 'PolyForm-Noncommercial-1.0.0'
        architecture = [ordered]@{
            '64bit' = [ordered]@{
                url = $PortableUrl
                hash = $PortableSha256.ToLowerInvariant()
            }
        }
        bin = @($Bin)
    }
    $manifestPath = Join-Path $bucketDir "$PackageId.json"
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM

    Invoke-Checked -FilePath 'git' -Operation 'bucket-git-init' -Arguments @('-C', $bucketRoot, 'init')
    Invoke-Checked -FilePath 'git' -Operation 'bucket-git-config-name' -Arguments @('-C', $bucketRoot, 'config', 'user.name', 'Foundry Lifecycle')
    Invoke-Checked -FilePath 'git' -Operation 'bucket-git-config-email' -Arguments @('-C', $bucketRoot, 'config', 'user.email', 'foundry-lifecycle@example.invalid')
    Invoke-Checked -FilePath 'git' -Operation 'bucket-git-add' -Arguments @('-C', $bucketRoot, 'add', 'bucket')
    Invoke-Checked -FilePath 'git' -Operation 'bucket-git-commit' -Arguments @('-C', $bucketRoot, 'commit', '-m', 'candidate')

    & $scoop bucket add foundry-candidate $bucketRoot
    if ($LASTEXITCODE -ne 0) { throw "scoop bucket add failed with exit code $LASTEXITCODE." }

    & $scoop install "foundry-candidate/$PackageId"
    if ($LASTEXITCODE -ne 0) { throw "scoop install failed with exit code $LASTEXITCODE." }

    $appCurrent = Join-Path $scoopRoot "apps\$PackageId\current"
    if (-not (Test-Path -LiteralPath $appCurrent -PathType Container)) { throw "Scoop current app directory is absent: $appCurrent" }
    foreach ($relative in $Bin) {
        $installed = Join-Path $appCurrent ($relative -replace '/', '\')
        if (-not (Test-Path -LiteralPath $installed -PathType Leaf)) { throw "Scoop-installed binary is absent: $installed" }
    }

    & $scoop install "foundry-candidate/$PackageId"
    if ($LASTEXITCODE -ne 0) { throw "repeat scoop install failed with exit code $LASTEXITCODE." }

    & $scoop uninstall $PackageId
    if ($LASTEXITCODE -ne 0) { throw "scoop uninstall failed with exit code $LASTEXITCODE." }

    $cleanupMs = Wait-Removed -Paths @((Join-Path $scoopRoot "apps\$PackageId"))
    $shimNames = @($Bin | ForEach-Object { [System.IO.Path]::GetFileName($_) })
    foreach ($shimName in $shimNames) {
        foreach ($candidate in @(
            (Join-Path $scoopRoot "shims\$shimName"),
            (Join-Path $scoopRoot "shims\$([System.IO.Path]::GetFileNameWithoutExtension($shimName)).shim"),
            (Join-Path $scoopRoot "shims\$([System.IO.Path]::GetFileNameWithoutExtension($shimName)).exe")
        )) {
            if (Test-Path -LiteralPath $candidate) { throw "Scoop uninstall left a shim behind: $candidate" }
        }
    }

    $evidence = [ordered]@{
        schemaVersion = 1
        client = 'scoop'
        packageId = $PackageId
        packageVersion = $PackageVersion
        artifactType = 'portable-zip'
        artifactUrl = $PortableUrl
        artifactSha256 = $PortableSha256.ToLowerInvariant()
        scoopInstallerCommit = $ScoopInstallerCommit.ToLowerInvariant()
        checks = [ordered]@{
            hashVerified = $true
            bucketAdded = 'passed'
            install = 'passed'
            binariesPresent = @($Bin)
            repeatInstall = 'passed'
            uninstall = 'passed'
            cleanup = 'passed'
        }
        cleanupConvergenceMilliseconds = [math]::Round($cleanupMs, 1)
        verdict = 'passed'
    }
    $evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $EvidencePath -Encoding utf8NoBOM
    Write-Host "Scoop lifecycle proof passed; evidence: $EvidencePath"
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
