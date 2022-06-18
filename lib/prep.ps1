function Init {
  if ($Hostname) {
    $name = "$Hostname"
  } else {
    $name = (Get-WmiObject win32_computersystem).DNSHostName +
      "." +
      (Get-WmiObject win32_computersystem).Domain
  }

  $script:dataPath = "$PSScriptRoot\..\data"

  Write-HeaderLine "Setting up workstation '$name'"

  Assert-NonAdministrativePrivileges
  Install-Gsudo
  Get-Sudo
}

function Install-Gsudo {
  if (-not (Get-Command gsudo -ErrorAction SilentlyContinue)) {
    Install-Scoop
    Install-Package "gsudo"
  }
}

function Set-Hostname {
  if (-not $Hostname) {
    return
  }

  $current = (Get-ComputerInfo).CsName
  if (-not ("$current" -eq "$Hostname")) {
    Write-HeaderLine "Setting hostname to '$Hostname"
    $newname = $Hostname.Split('.')[0]
    gsudo Rename-Computer -NewName "$newname" -Confirm

    Write-WarnLine ""
    Write-WarnLine `
      "Setting hostname requires restart. Reboot, then re-run $program"
    Write-WarnLine ""
    Write-Failure "Reboot Required"
  }
}

function Initialize-PackageSystem {
  Write-HeaderLine "Setting up package systems"

  Install-Scoop
  Install-Chocolatey
}

function Install-Scoop {
  if (-not (Test-Command scoop)) {
    Write-InfoLine "Installing the Scoop command-line installer"

    Set-ExecutionPolicy RemoteSigned -scope CurrentUser -Force
    Invoke-RestMethod https://get.scoop.sh | Invoke-Expression
  }

  $buckets = @(scoop bucket list | ForEach-Object { $_.Name })
  foreach ($bucket in @("extras", "nerd-fonts")) {
    if (-not ($buckets -contains "$bucket")) {
      Write-InfoLine "Adding Scoop bucket '$bucket"
      scoop bucket add "$bucket"
    }
  }
}

function Install-Chocolatey {
  if (-not (Test-Command choco)) {
    Write-InfoLine "Installing the Chocolatey package manager"

    Confirm-Command gsudo

    Invoke-gsudo {
      $env:chocolateyUseWindowsCompression = 'true'
      Set-ExecutionPolicy Bypass -Scope Process -Force
      [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
      Invoke-Expression ((New-Object System.Net.WebClient).
        DownloadString('https://chocolatey.org/install.ps1'))
    }
  }
}

function Update-System {
  Write-HeaderLine "Applying system updates"

  if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-InfoLine "Installing PSWindowsUpdate commandlet"
    gsudo Install-PackageProvider -Name NuGet -Force
    gsudo Install-Module PSWindowsUpdate -Force
  }

  Write-InfoLine "Installing Windows updates"
  # TODO fn: stop this from blocking
  Invoke-gsudo { Get-WUInstall -AcceptAll -AutoReboot -Verbose }

  Write-InfoLine "Updating Scoop packages"
  Confirm-Command scoop
  Install-Package git
  scoop update
  scoop update --all

  Write-InfoLine "Updating Chocolatey packages"
  Confirm-Command choco
  gsudo choco upgrade all
}

function Install-BasePackages {
  Write-HeaderLine "Installing base packages"
  Install-PkgsFromJson "$dataPath\windows_base_pkgs.json"

  if (-not (Get-Module -ListAvailable -Name posh-git)) {
    Write-InfoLine "Installing posh-git module"
    gsudo Install-Module posh-git -Force
  }
}

function Set-Preferences {
  Write-HeaderLine "Setting preferences"

  # TODO fn: implement!
  Write-Host "Set-Preferences not implemented yet"
}

# @TODO(fnichol): finish up!
function Install-SSH {
  Write-HeaderLine "Setting up SSH"

  if (-not (Test-Path $env:SystemDrive\Windows\System32\OpenSSH)) {
    Write-InfoLine "Installing OpenSSH.Client"
    Add-WindowsCapability -Online -Name OpenSSH.Client*
    Write-InfoLine "Installing OpenSSH.Client"
    Add-WindowsCapability -Online -Name OpenSSH.Server*

    Write-InfoLine "Starting and enabling sshd service"
    Start-Service -Name sshd
    Set-Service -Name sshd -StartupType 'Automatic'

    Write-InfoLine "Setting default shell to PowerShell for OpenSSH"
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
      -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
      -PropertyType String -Force
  }
}

function Invoke-BaseFinalize {
  Write-HeaderLine "Finalizing base setup"
}

function Install-HeadlessPackages {
  Write-HeaderLine "Installing headless packages"
  Install-PkgsFromJson "$dataPath\windows_headless_pkgs.json"
  Install-ChocolateyPkgsFromJson `
    "$dataPath\windows_headless_chocolatey_pkgs.json"
  Install-Wsl
}

function Install-Wsl {
  $wslstate = Invoke-gsudo {
    (Get-WindowsOptionalFeature -Online `
      -FeatureName Microsoft-Windows-Subsystem-Linux).State
  }

  # Install Windows Subsystem for Linux if it is disabled
  if ($wslstate.Value -eq "Disabled") {
    Write-InfoLine "Enabling 'wsl'"
    Invoke-gsudo {
      Enable-WindowsOptionalFeature -Online `
        -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
    }

    Write-WarnLine ""
    Write-WarnLine "Enabling WSL requires restart. Reboot, then re-run $program"
    Write-WarnLine ""
    Write-Failure "Reboot Required"
  }

  Install-Package "archwsl"
}

function Install-Rust {
  $cargo_home = "$env:USERPROFILE\.cargo"
  $rustup = "$cargo_home\bin\rustup.exe"
  $cargo = "$cargo_home\bin\cargo.exe"

  Write-HeaderLine "Setting up Rust"

  if (-not (Test-Path "$rustup")) {
    Write-InfoLine "Installing Rust"
    & ([scriptblock]::Create((New-Object System.Net.WebClient).DownloadString(
      'https://gist.github.com/fnichol/699d3c2930649a9932f71bab8a315b31/raw/rustup-init.ps1')
      )) -y --default-toolchain stable
  }

  & "$rustup" self update
  & "$rustup" update

  & "$rustup" component add rust-src
  & "$rustup" component add rustfmt

  $plugins = Get-Content "$dataPath\rust_cargo_plugins.json" `
    | ConvertFrom-Json
  foreach ($plugin in $plugins) {
    if (-not (& "$cargo" install --list | Select-String -Pattern "$plugin")) {
      Write-InfoLine "Installing $plugin"
      & "$cargo" install --verbose "$plugin"
    }
  }
}

function Install-Ruby {
  Write-HeaderLine "Setting up Ruby"
  Install-Package "ruby"
}

function Install-Go {
  Write-HeaderLine "Setting up Go"
  Install-Package "go"
}

function Install-Node {
  Write-HeaderLine "Setting up Node"
  Install-Package "nodejs"
}

function Invoke-HeadlessFinalize {
  Write-HeaderLine "Finalizing headless setup"
}

function Install-GraphicalPackages {
  Write-HeaderLine "Installing graphical packages"
  Install-PkgsFromJson "$dataPath\windows_graphical_pkgs.json"
  Install-ChocolateyPkgsFromJson `
    "$dataPath\windows_graphical_chocolatey_pkgs.json"
}

function Invoke-GraphicalFinalize {
  Write-HeaderLine "Finalizing graphical setup"
}

function Finish {
  Write-HeaderLine "Finished setting up workstation, enjoy!"
}

function Install-Package($Pkg) {
  Install-WindowsPackage "$Pkg"
}

function Install-WindowsPackage($Pkg) {
  Install-ScoopPackage($Pkg)
}

function Install-ScoopPackage($Pkg) {
  $installed = @(
    @(scoop export) | ForEach-Object { $_.split(' (')[0] }
  )

  if ($installed -contains "$Pkg") {
    return
  }

  Write-InfoLine "Installing Scoop package '$Pkg'"
  scoop install "$Pkg"
}

function Install-ChocolateyPackage($Pkg) {
  $installed = @(
    @(choco list --limit-output --local-only) |
      ForEach-Object { $_.split('|')[0] }
  )

  if ($installed -contains "$Pkg") {
    return
  }

  Write-InfoLine "Installing Chocolatey package '$Pkg'"
  gsudo choco install -y "$Pkg"
}

function Install-PkgsFromJson($Json) {
  $pkgs = Get-Content "$Json" | ConvertFrom-Json

  foreach ($pkg in $pkgs) {
    Install-Package "$pkg"
  }
}

function Install-ChocolateyPkgsFromJson($Json) {
  $pkgs = Get-Content "$Json" | ConvertFrom-Json

  foreach ($pkg in $pkgs) {
    Install-ChocolateyPackage "$pkg"
  }
}
