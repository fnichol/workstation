Param(
  [Switch]
  $help,

  [Switch]
  $baseOnly,

  [parameter(Position=0)]
  [String[]]
  $hostname
)

function main {
  $script:program = "prep"
  $script:version = "0.5.0"
  $script:author = "Fletcher Nichol <fnichol@nichol.ca>"

  . "$PSScriptRoot\..\lib\common.ps1"
  . "$PSScriptRoot\..\lib\prep.ps1"

  Parse-CLIArguments

  Init
  Set-Hostname
  Setup-PackageSystem
  Update-System
  Install-BasePackages
  Set-Preferences

  if (!$baseOnly) {
    Install-WorkstationPackages
    Install-Habitat
    Install-Rust
    Install-Ruby
    Install-Go
    Install-Node
  }

  Finish
}

main
