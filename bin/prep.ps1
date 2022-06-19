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
              SSH, BaseFinalize, HeadlessPkgs, Rust, Ruby, Go,
              Node, HeadlessFinalize, GraphicalPkgs, GraphicalFinalize]

.PARAMETER Only
    Single tasks to run
    [values:  Hostname, PkgInit, UpdateSystem, BasePkgs, Preferences,
              SSH, BaseFinalize, HeadlessPkgs, Rust, Ruby, Go,
              Node, HeadlessFinalize, GraphicalPkgs, GraphicalFinalize]

.PARAMETER Hostname
    Hostname for system

.PARAMETER NoReboot
    Avoid restarting system, even when it might be necessary
#>

param (
  [ValidateSet("Base", "Headless", "Graphical")]
  [string]$Profile = "Graphical",

  [ValidateSet("Hostname", "PkgInit", "UpdateSystem", "BasePkgs", "Preferences",
    "SSH", "BaseFinalize", "HeadlessPkgs", "Rust", "Ruby", "Go", "Node",
    "HeadlessFinalize", "GraphicalPkgs", "GraphicalFinalize")]
  [AllowEmptyCollection()]
  [string[]]$Skip = @(),

  [ValidateSet("Hostname", "PkgInit", "UpdateSystem", "BasePkgs", "Preferences",
    "SSH", "BaseFinalize", "HeadlessPkgs", "Rust", "Ruby", "Go", "Node",
    "HeadlessFinalize", "GraphicalPkgs", "GraphicalFinalize")]
  [AllowEmptyCollection()]
  [string[]]$Only = @(),

  [string]$Hostname,

  [switch]$NoReboot
)

function Invoke-Main {
  $script:program = "prep"

  . "$PSScriptRoot\..\lib\common.ps1"
  . "$PSScriptRoot\..\lib\prep.ps1"

  Init

  try {
    if (Test-InvokeTask "Hostname")     { Set-Hostname }
    if (Test-InvokeTask "PkgInit")      { Initialize-PackageSystem }
    if (Test-InvokeTask "UpdateSystem") { Update-System }
    if (Test-InvokeTask "BasePkgs")     { Install-BasePackages }
    if (Test-InvokeTask "Preferences")  { Set-Preferences }
    if (Test-InvokeTask "SSH")          { Install-SSH }
    if (Test-InvokeTask "BaseFinalize") { Invoke-BaseFinalize }

    if (($Profile -eq "Headless") -or ($Profile -eq "Graphical")) {
      if (Test-InvokeTask "HeadlessPkgs")     { Install-HeadlessPackages }
      if (Test-InvokeTask "Rust")             { Install-Rust }
      if (Test-InvokeTask "Ruby")             { Install-Ruby }
      if (Test-InvokeTask "Go")               { Install-Go }
      if (Test-InvokeTask "Node")             { Install-Node }
      if (Test-InvokeTask "HeadlessFinalize") { Invoke-HeadlessFinalize }
    }

    if ($Profile -eq "Graphical") {
      if (Test-InvokeTask "GraphicalPkgs") { Install-GraphicalPackages }
      if (Test-InvokeTask "GraphicalFinalize") { Invoke-GraphicalFinalize }
    }

    Finish
  } finally {
    Invoke-Cleanup
  }
}

Invoke-Main
