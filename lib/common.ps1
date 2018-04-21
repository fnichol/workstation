function Ensure-AdministratorPrivileges {
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

  if (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-WarnLine "$program must be run in a PowerShell session with administrator privileges."
    Write-WarnLine "Please re-run to try again."
    Exit-With "Program run without administrator privileges" 1
  }
}

function Exit-With {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True)]
    [string]
    $Message,

    [Parameter(Mandatory=$True)]
    [int32]
    $ExitCode
  )

  process {
    Write-Error "ERROR: $Message"
    exit $ExitCode
  }
}

function Write-HeaderLine($Message) {
  Write-Host "-----> $Message" -ForegroundColor Cyan
}

function Write-InfoLine($Message) {
  Write-Host "       $Message" -ForegroundColor Cyan
}

function Write-WarnLine($Message) {
  Write-Warning " !!!   $Message" -ForegroundColor Yellow
}
