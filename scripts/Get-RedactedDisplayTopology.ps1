#requires -Version 5.1
<#
.SYNOPSIS
  Read-only, anonymous Windows monitor geometry for adaptive presentation.
.DESCRIPTION
  No serial, EDID, monitor name, desktop coordinates, window titles, active app,
  device identifiers or frame captures. Enumerated virtual/remote monitors are
  not proof of physical panels. Synthetic -Displays is available for testing.
#>
[CmdletBinding()]
param([object[]]$Displays=@(),[switch]$Live)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Live.IsPresent -and $Displays.Count -ne 0){throw 'Live/synthetic sources cannot mix'}
$source='synthetic'
if($Live.IsPresent){
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $Displays=@([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
        [pscustomobject]@{
            Width=[int]$_.Bounds.Width
            Height=[int]$_.Bounds.Height
            Primary=[bool]$_.Primary
        }
    })
    $source='windows-forms-screen-observed'
}
if($Displays.Count -eq 0 -or $Displays.Count -gt 8){throw 'Invalid display count'}
$redacted=@()
$primaryCount=0
foreach($d in $Displays){
    $w=[int]$d.Width
    $h=[int]$d.Height
    if($w -lt 160 -or $w -gt 16384 -or $h -lt 160 -or $h -gt 16384){
        throw 'Invalid geometry'
    }
    if($d.Primary -ne $true -and $d.Primary -ne $false){throw 'Invalid primary flag'}
    if($d.Primary){$primaryCount++}
    $redacted+= [ordered]@{width=$w;height=$h;primary=[bool]$d.Primary}
}
if($primaryCount -ne 1){throw 'Exactly one primary required'}
[ordered]@{
    schema='windows-display-topology-observation/v1'
    source=$source
    displays=$redacted
    deviceNamesIncluded=$false
    deviceSerialsIncluded=$false
    physicalMonitorsAttested=$false
    workcellAuthorityGranted=$false
    humanApprovalAuthenticated=$false
} | ConvertTo-Json -Depth 5 -Compress
