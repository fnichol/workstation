<#
.SYNOPSIS
    Workstation setup

.DESCRIPTION
    This program sets up a workstation

.PARAMETER Profile
    Setup profile
    [values: Base, Headless, Graphical]
    [default: Graphical]

.PARAMETER Skip
    Tasks to skip
    [values:  Hostname, PkgInit, UpdateSystem, BasePkgs, Preferences,
              HeadlessPkgs, Rust, Ruby, Go, Node, GraphicalPkgs]

.PARAMETER Only
    Single tasks to run
    [values:  Hostname, PkgInit, UpdateSystem, BasePkgs, Preferences,
              HeadlessPkgs, Rust, Ruby, Go, Node, GraphicalPkgs]
#>

param (
  [ValidateSet("Base", "Headless", "Graphical")]
  [string]$Profile = "Graphical",

  [ValidateSet("Hostname", "PkgInit", "UpdateSystem", "BasePkgs", "Preferences",
    "HeadlessPkgs", "Rust", "Ruby", "Go", "Node", "GraphicalPkgs")]
  [AllowEmptyCollection()]
  [string[]]$Skip = @(),

  [ValidateSet("Hostname", "PkgInit", "UpdateSystem", "BasePkgs", "Preferences",
    "HeadlessPkgs", "Rust", "Ruby", "Go", "Node", "GraphicalPkgs")]
  [AllowEmptyCollection()]
  [string[]]$Only = @()
)

function Invoke-Main {
  $script:program = "prep"

  . "$PSScriptRoot\..\lib\common.ps1"
  . "$PSScriptRoot\..\lib\prep.ps1"

  Init

  if (Test-InvokeTask "Hostname")     { Set-Hostname }
  if (Test-InvokeTask "PkgInit")      { Init-PackageSystem }
  if (Test-InvokeTask "UpdateSystem") { Update-System }
  if (Test-InvokeTask "BasePkgs")     { Install-BasePackages }
  if (Test-InvokeTask "Preferences")  { Set-Preferences }

  if (($Profile -eq "Headless") -or ($Profile -eq "Graphical")) {
    if (Test-InvokeTask "HeadlessPkgs") { Install-HeadlessPackages }
    if (Test-InvokeTask "Rust")         { Install-Rust }
    if (Test-InvokeTask "Ruby")         { Install-Ruby }
    if (Test-InvokeTask "Go")           { Install-Go }
    if (Test-InvokeTask "Node")         { Install-Node }
  }

  if ($Profile -eq "Graphical") {
    if (Test-InvokeTask "GraphicalPkgs") { Install-GraphicalPackages }
  }

  Finish
}

Invoke-Main
