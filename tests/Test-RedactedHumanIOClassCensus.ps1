#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/Get-RedactedHumanIOClassCensus.ps1'
$synthetic = @(
    [pscustomobject]@{Class='HIDClass';FriendlyName='SECRET-DEVICE-NAME';InstanceId='SECRET-DEVICE-SERIAL'},
    [pscustomobject]@{Class='Keyboard';FriendlyName='REDACT-ME';PNPDeviceID='PRIVATE-SERIAL'},
    [pscustomobject]@{Class='Mouse';FriendlyName='USER-HARDWARE-IDENTITY'},
    [pscustomobject]@{Class='OtherSecret';FriendlyName='NO-LEAK'}
)
$raw = & $script -Devices $synthetic
$census = $raw | ConvertFrom-Json
if ($census.schema -ne 'windows-human-io-class-census/v1') { throw 'Wrong schema' }
if ($census.source -ne 'synthetic') { throw 'Synthetic/hardware source confusion' }
if (@($census.results).Count -ne 11) { throw 'Wrong class count' }
foreach ($sensitive in @('SECRET','PRIVATE','REDACT','FRIENDLY','PNPDEVICEID')) {
    if ($raw.ToUpperInvariant().Contains($sensitive)) { throw 'Source identity leaked into public receipt' }
}
if (($census.results | Where-Object { $_.deviceClass -eq 'HIDClass' }).presentCount -ne 1) {
    throw 'Wrong HIDClass tally'
}
foreach ($flag in @('rawDeviceIdentifiersIncluded','humanApprovalAuthenticated',
                     'permissionGranted','physicalSensorExercised',
                     'toolAuthorityGranted','productionAdmitted')) {
    if ($census.$flag -ne $false) { throw "False authority claim: $flag" }
}
try {
    & $script -Devices $synthetic -Live | Out-Null
    throw 'Illegal synthetic/live source mixing was allowed'
} catch {
    if ($_.Exception.Message -notlike '*mutually exclusive*') { throw }
}
Write-Output '{"schema":"windows-human-io-census-test/v1","result":"PASS","identity_leak":false,"physical_hil":false,"production_admitted":false}'
