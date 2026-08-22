#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ArtifactRoot,
    [Parameter(Mandatory)] [string] $OutputDirectory,
    [Parameter(Mandatory)] [string] $SubjectPath,
    [string] $ActionRepository,
    [string] $ActionRef,
    [string] $Repository,
    [string] $SourceSha,
    [string] $Ref,
    [string] $RefName,
    [string] $Workflow,
    [string] $WorkflowRef,
    [string] $WorkflowSha,
    [string] $RunId,
    [string] $RunAttempt,
    [string] $RunnerOs
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

function Get-FullPathWithSeparator {
    param([Parameter(Mandatory)] [string] $Path)
    $full = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    return $full + [IO.Path]::DirectorySeparatorChar
}

$artifactRootFull = [IO.Path]::GetFullPath($ArtifactRoot)
$outputDirectoryFull = [IO.Path]::GetFullPath($OutputDirectory)

if (-not (Test-Path -LiteralPath $artifactRootFull -PathType Container)) {
    throw "Artifact root does not exist: $artifactRootFull"
}

$comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$artifactPrefix = Get-FullPathWithSeparator -Path $artifactRootFull
$outputPrefix = Get-FullPathWithSeparator -Path $outputDirectoryFull

if ($outputDirectoryFull.Equals($artifactRootFull, $comparison) -or $outputPrefix.StartsWith($artifactPrefix, $comparison)) {
    throw 'OutputDirectory must be outside ArtifactRoot so trust files cannot recursively enter the release inventory.'
}

if (Test-Path -LiteralPath $outputDirectoryFull) {
    $existing = @(Get-ChildItem -LiteralPath $outputDirectoryFull -Force -ErrorAction Stop)
    if ($existing.Count -gt 0) {
        throw "OutputDirectory must be empty at action start: $outputDirectoryFull"
    }
} else {
    New-Item -ItemType Directory -Path $outputDirectoryFull -Force | Out-Null
}

$files = @(
    Get-ChildItem -LiteralPath $artifactRootFull -Recurse -File -Force |
        ForEach-Object {
            if (($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Release inventory contains a reparse point/symlink, which is not allowed in the MVP trust envelope: $($_.FullName)"
            }
            $relative = [IO.Path]::GetRelativePath($artifactRootFull, $_.FullName).Replace('\', '/')
            [pscustomobject]@{
                File = $_
                RelativePath = $relative
            }
        } |
        Sort-Object -Property RelativePath
)

if ($files.Count -eq 0) {
    throw 'ArtifactRoot contains no files to inventory.'
}

$checksumLines = [Collections.Generic.List[string]]::new()
foreach ($entry in $files) {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $entry.File.FullName).Hash.ToLowerInvariant()
    $checksumLines.Add("$hash  $($entry.RelativePath)")
}

$checksumsPath = Join-Path $outputDirectoryFull 'foundry-checksums.sha256'
Write-Utf8NoBom -Path $checksumsPath -Content (($checksumLines -join "`n") + "`n")
$checksumsSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $checksumsPath).Hash.ToLowerInvariant()

$context = [ordered]@{
    schemaVersion = 1
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    repository = $Repository
    sourceSha = $SourceSha
    ref = $Ref
    refName = $RefName
    workflow = $Workflow
    workflowRef = $WorkflowRef
    workflowSha = $WorkflowSha
    runId = $RunId
    runAttempt = $RunAttempt
    runnerOs = $RunnerOs
    foundryActionRepository = $ActionRepository
    foundryActionRef = $ActionRef
    artifactRootName = (Split-Path -Leaf $artifactRootFull)
    inventoriedFileCount = $files.Count
    checksumAlgorithm = 'sha256'
    checksumManifest = 'foundry-checksums.sha256'
    checksumManifestSha256 = $checksumsSha
    subjectSelectionProvided = -not [string]::IsNullOrWhiteSpace($SubjectPath)
}

$contextPath = Join-Path $outputDirectoryFull 'foundry-build-context.json'
Write-Utf8NoBom -Path $contextPath -Content (($context | ConvertTo-Json -Depth 20) + "`n")

Write-Host "Foundry release inventory: $($files.Count) files"
Write-Host "Checksums: $checksumsPath"
Write-Host "Build context: $contextPath"
