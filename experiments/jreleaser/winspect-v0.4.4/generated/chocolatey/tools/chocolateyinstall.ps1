# Generated with JReleaser 1.25.0
$toolsDir   = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName   = 'wininspect'
  fileType      = 'exe'
  url           = 'https://github.com/SemperSupra/WinInspect/releases/download/v0.4.4/WinInspect-Installer-v0.4.4.exe'
  silentArgs    = "/quiet"
  validExitCodes= @(0)
  softwareName  = 'wininspect*'
  checksum      = '601d5f54083ea8922328b8b35d9094b8fb2eb8e8d243dd0883de90fb9919acba'
  checksumType  = 'sha256'
}

Install-ChocolateyPackage @packageArgs
