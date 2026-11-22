#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script=Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/Get-RedactedDisplayTopology.ps1'
$synthetic=@(
 [pscustomobject]@{Width=2560;Height=1440;Primary=$true;Name='PRIVATE-DISPLAY-SERIAL'},
 [pscustomobject]@{Width=1920;Height=1080;Primary=$false;EDID='SECRET-EDID';X=-1920},
 [pscustomobject]@{Width=1200;Height=1920;Primary=$false;WindowTitle='PRIVATE-WINDOW'}
)
$json=& $script -Displays $synthetic
$parsed=$json | ConvertFrom-Json
if(@($parsed.displays).Count -ne 3){throw 'Incorrect multi-monitor count'}
if(@($parsed.displays | Where-Object {$_.primary}).Count -ne 1){throw 'Incorrect primary'}
if(@($parsed.displays | Where-Object {$_.width -eq 1200}).Count -ne 1){throw 'Portrait geometry lost'}
foreach($word in @('PRIVATE','SECRET','EDID','WINDOW','SERIAL','Name','X')){
    # 'Name' and 'X' are not JSON fields, test as quoted keys rather than arbitrary chars
    if($word -in @('Name','X')){
       if($json.Contains(('"' + $word + '"'))){throw 'Extraneous key leaked'}
    }elseif($json.Contains($word)){throw 'Sensitive monitor identifier leaked'}
}
if($parsed.physicalMonitorsAttested -or $parsed.workcellAuthorityGranted -or $parsed.humanApprovalAuthenticated){
 throw 'False physical / approval authority claim'
}
try {
  & $script -Displays $synthetic -Live | Out-Null
  throw 'Mixed observation sources admitted'
}catch{
  if($_.Exception.Message -notlike '*cannot mix*'){throw}
}
try{
 & $script -Displays @([pscustomobject]@{Width=50;Height=100;Primary=$true}) | Out-Null
 throw 'Invalid geometry admitted'
}catch{
 if($_.Exception.Message -notlike '*Invalid geometry*'){throw}
}
Write-Output '{"schema":"windows-display-topology-test/v1","state":"PASS","physical_hil":false,"authority":false}'
