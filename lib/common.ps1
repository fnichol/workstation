function Test-Command([Parameter(Mandatory=$True)] [string]$Command) {
  Get-Command "$Command" -ErrorAction SilentlyContinue
}

function Confirm-Command([Parameter(Mandatory=$True)] [string]$Command) {
  if (-not (Test-Command "$Command")) {
    Write-Failure "Required command '$Command' not found"
  }
}

function Test-AdministrativePrivileges {
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
  $admin = [Security.Principal.WindowsBuiltInRole]::Administrator

  $currentPrincipal.IsInRole($admin)
}

function Assert-NonAdministrativePrivileges {
  if (Test-AdministrativePrivileges) {
    Write-WarnLine "$program must *not* be run in a PowerShell session with " +
      "administrator privileges. Please re-run to try again."
    Write-Failure "Program run with administrator privileges"
  }
}

function Get-Sudo {
  Write-HeaderLine "Starting gsudo credentials cache session"

  Confirm-Command "gsudo"
  gsudo cache on
}

function Test-InvokeTask([string]$Task) {
  if ($Only.Length -gt 0) {
    (($Only.Contains($Task)) -and (-not ($Skip.Contains($Task))))
  } else {
    -not ($Skip.Contains($Task))
  }
}

function Invoke-Cleanup {
  if (Get-Command gsudo -ErrorAction SilentlyContinue) {
    Write-HeaderLine "Stopping gsudo credentials cache session"
    # Ends the gsudo credentials cache session
    gsudo cache off
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
