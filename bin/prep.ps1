<#
.SYNOPSIS
Workstation setup

.DESCRIPTION
This program sets up a workstation

.EXAMPLE
.\bin\prep.ps1 mydevhost
#>

param (
  # Only sets up base system (not extra workstation setup)
  [switch]$BaseOnly,

  # The name for this workstation
  [parameter(Position=0)]
  [string]$Hostname
)

function main {
  $script:program = "prep"

  . "$PSScriptRoot\..\lib\common.ps1"
  . "$PSScriptRoot\..\lib\prep.ps1"

  Init
  Set-Hostname
  Setup-PackageSystem
  Update-System
  Install-BasePackages
  Set-Preferences

  if (!$BaseOnly) {
    Install-WorkstationPackages
    Install-Rust
    Install-Ruby
    Install-Go
    Install-Node
  }

  Finish
}

main
