#requires -Version 5.1
<#
.SYNOPSIS
  R43 read-only, redacted PnP class census for Windows human input/output.
.DESCRIPTION
  Emits only allowlisted class counts, never device identifiers, PNPDeviceID,
  friendly names, serials, paths or user metadata. Class-level presence is
  NOT sensor exercise, consent, physical HID attestation or tool authority.
  -Devices is synthetic source-only qualification; -Live is Windows runner HIL
  *class observation only*. Does not enable or access any device.
#>
[CmdletBinding()]
param(
    [object[]]$Devices = @(),
    [switch]$Live
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Live.IsPresent -and $Devices.Count -gt 0) {
    throw 'Live and synthetic inventories are mutually exclusive'
}
$classes = @('HIDClass', 'Keyboard', 'Mouse', 'Camera', 'Image', 'Media',
             'AudioEndpoint', 'Bluetooth', 'Sensor', 'Monitor', 'Biometric')
$counts = [ordered]@{}
foreach ($name in $classes) { $counts[$name] = 0 }
$source = 'synthetic'
if ($Live.IsPresent) {
    if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        throw 'Live Windows PnP census requires Windows'
    }
    $cmd = Get-Command Get-PnpDevice -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { throw 'Windows PnP discovery unavailable' }
    # Deliberately never retain the full device object beyond this iteration.
    $source = 'windows-pnpclass-present-only'
    foreach ($device in (Get-PnpDevice -PresentOnly -ErrorAction Stop)) {
        $class = [string]$device.Class
        if ($counts.Contains($class)) { $counts[$class]++ }
    }
} else {
    foreach ($device in $Devices) {
        if ($null -eq $device) { continue }
        $class = [string]$device.Class
        if ($counts.Contains($class)) { $counts[$class]++ }
    }
}
$entries = @()
foreach ($name in $classes) {
    $entries += [ordered]@{
        deviceClass = $name
        presentCount = [int]$counts[$name]
        classification = 'PnP_CLASS_ONLY_NOT_HID_OR_PHYSICAL_EXERCISE'
    }
}
[ordered]@{
    schema = 'windows-human-io-class-census/v1'
    source = $source
    platform = 'windows'
    results = $entries
    rawDeviceIdentifiersIncluded = $false
    humanApprovalAuthenticated = $false
    permissionGranted = $false
    physicalSensorExercised = $false
    toolAuthorityGranted = $false
    productionAdmitted = $false
} | ConvertTo-Json -Depth 6 -Compress
