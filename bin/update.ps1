<#
.SYNOPSIS
    Updates the working copy of this project

.DESCRIPTION
    This program updates the working copy of this project
#>

function Invoke-Main {
  $script:program = "update"

  . "$PSScriptRoot\..\lib\common.ps1"

  Write-HeaderLine "Updating repository checkout"

  Confirm-Command git
  Write-InfoLine "git fetch origin"
  git fetch origin
  Write-InfoLine "git rebase origin/master"
  git rebase origin/master

  Write-HeaderLine "Finished updating"
}

Invoke-Main
