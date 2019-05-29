function Ensure-AdministratorPrivileges {
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

  if (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-WarnLine "$program must be run in a PowerShell session with administrator privileges."
    Write-WarnLine "Please re-run to try again."
    Write-Failure "Program run without administrator privileges"
  }
}

function Write-Failure([Parameter(Mandatory=$True)] [string]$Message) {
  Write-Error "$Message"
  throw
}

function Write-HeaderLine($Message) {
  Write-Host "--- " -ForegroundColor Cyan -NoNewline
  Write-Host "$Message" -ForegroundColor White
}

function Write-InfoLine($Message) {
  Write-Host "  - " -ForegroundColor Cyan -NoNewline
  Write-Host "$Message" -ForegroundColor White
}

function Write-WarnLine($Message) {
  Write-Warning "$Message"
}
