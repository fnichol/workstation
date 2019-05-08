function Write-Help {
  Write-Host @"
$program $version

$author

Workstation Setup

USAGE:
        $program [FLAGS] [OPTIONS] [<FQDN>]

FLAGS:
    -b  Only sets up base system (not extra workstation setup)
    -h  Prints this message

ARGS:
    <FQDN>    The name for this workstation

"@
}

function Parse-CLIArguments {
  if ($help) {
    Write-Help
    exit
  }
}

function Init {
  if ($hostname) {
    $name = "$hostname"
  } else {
    $name = (Get-WmiObject win32_computersystem).DNSHostName +
      "." +
      (Get-WmiObject win32_computersystem).Domain
  }

  $script:dataPath = "$PSScriptRoot\..\data"

  Write-HeaderLine "Setting up workstation '$name'"

  Ensure-AdministratorPrivileges
}

function Set-Hostname {
  if (-not $hostname) {
    return
  }

  # TODO fn: implement!
  Write-Host "Set-Hostname not implemented yet"
}

function Setup-PackageSystem {
  Write-HeaderLine "Setting up package system"

  if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).
      DownloadString('https://chocolatey.org/install.ps1'))
  }
}

function Update-System {
  Write-HeaderLine "Applying system updates"

  if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -Force
    Install-Module PSWindowsUpdate -Force
  }

  # TODO fn: stop this from blocking
  # Get-WUInstall -AcceptAll -AutoReboot -Verbose
}

function Install-BasePackages {
  Write-HeaderLine "Installing base packages"
  Install-PkgsFromJson "$dataPath\windows_base_pkgs.json"

  if (-not (Get-Module -ListAvailable -Name posh-git)) {
    Install-Module posh-git -Force
  }
}

function Set-Preferences {
  Write-HeaderLine "Setting preferences"

  # TODO fn: implement!
  Write-Host "Set-Preferences not implemented yet"
}

function Install-WorkstationPackages {
  Write-HeaderLine "Installing workstation packages"
  Install-PkgsFromJson "$dataPath\windows_workstation_pkgs.json"

  $wslstate = (Get-WindowsOptionalFeature -Online `
    -FeatureName Microsoft-Windows-Subsystem-Linux).State

  # Install Windows Subsystem for Linux if it is disabled
  if ($wslstate -eq "Disabled") {
    Write-InfoLine "Installing 'Microsoft-Windows-Subsystem-Linux'"
    Enable-WindowsOptionalFeature -Online `
      -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
  }

  $wsldistro = "wsl-ubuntu-1804"
  $wslroot = "$env:SystemDrive\Distros"
  $wsldst = "$wslroot\$wsldistro"

  # Download and install the Linux distribution if not found
  if (-not (Test-Path "$wsldst")) {
    $wslzip = "$env:TEMP\$wsldistro.zip"

    Write-InfoLine "Downloading '$wsldistro'"
    # Disable download progress bar which slows the download
    $ProgressPreference = 'silentlyContinue'
    Invoke-WebRequest -Uri "https://aka.ms/$wsldistro" `
      -OutFile "$wslzip" -UseBasicParsing
    $ProgressPreference = 'Continue'
    if (-not (Test-Path "$wslroot")) {
      New-Item -ItemType directory -Path "$wslroot"
    }
    Write-InfoLine "Extracting '$wsldistro' into $wsldst"
    Expand-Archive "$wslzip" "$wsldst"
    Remove-Item "$wslzip"
  }
}

function Install-Rust {
  $rustc = "$env:HOMEPATH\.cargo\bin\rustc.exe"
  $cargo = "$env:HOMEPATH\.cargo\bin\cargo.exe"
  $rustup = "$env:HOMEPATH\.cargo\bin\rustup.exe"

  Write-HeaderLine "Setting up Rust"

  # Need the Visual C 2013 Runtime for the Win32 ABI Rust
  Install-Package "vcredist2013" "--allowemptychecksum"

   # Need the Visual C++ tools to build Rust crates (provides a
   # compiler and linker)
  Install-Package "visualcppbuildtools" "--version '14.0.25123' --allowemptychecksum"

  if (-not (Test-Path "$rustc")) {
    Write-InfoLine "Installing Rust"
    Push-Location "$env:TEMP"
    try {
      Invoke-RestMethod -UseBasicParsing -OutFile "rustup-init.exe" `
        'https://static.rust-lang.org/rustup/dist/i686-pc-windows-gnu/rustup-init.exe'
      .\rustup-init.exe -y --default-toolchain stable
      Remove-Item .\rustup-init.exe -Force
    }
    finally { Pop-Location }
  }

  & "$rustup" self update
  & "$rustup" update

  & "$rustup" component add rust-src
  & "$rustup" component add rustfmt

  foreach ($plugin in @("cargo-watch","cargo-edit","cargo-outdated")) {
    if (-not (& "$cargo" install --list | Select-String -Pattern "$plugin")) {
      Write-InfoLine "Installing $plugin"
      & "$cargo" install "$plugin"
    }
  }
}

function Install-Ruby {
  Write-HeaderLine "Setting up Ruby"
  Install-Package "ruby"
}

function Install-Go {
  Write-HeaderLine "Setting up Go"
  Install-Package "golang"
}

function Install-Node {
  Write-HeaderLine "Setting up Node"
  Install-Package "nodejs-lts"
}

function Finish {
  Write-HeaderLine "Finished setting up workstation, enjoy!"
}

function Install-PkgsFromJson($Json) {
  $pkgs = Get-Content "$Json" | ConvertFrom-Json

  foreach ($pkg in $pkgs) {
    Install-Package "$pkg"
  }
}

function Install-Package($Pkg, $OtherArgs) {
  $installed = @(
    @(choco list --limit-output --local-only) | % { $_.split('|')[0] }
  )

  if ($installed -contains "$Pkg") {
    return
  }

  Write-InfoLine "Installing package '$Pkg'"
  if ($OtherArgs) {
    Invoke-Expression "choco install -y $Pkg $OtherArgs"
  } else {
    choco install -y "$Pkg"
  }
}
