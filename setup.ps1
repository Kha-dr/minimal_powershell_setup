param(
    [switch]$ProfileOnly
)

# Check if the script is running as administrator
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Definition
    if (-not $scriptPath) {
        Write-Error 'Please run this setup command from an elevated (Administrator) PowerShell.'
        exit 1
    }

    Write-Host 'Script is not running as administrator. Relaunching with elevated privileges...'
    $exe = (Get-Process -Id $PID).Path
    $profileFlag = if ($ProfileOnly) { ' -ProfileOnly' } else { '' }
    $argumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"$profileFlag"
    Start-Process -FilePath $exe -ArgumentList $argumentList -Verb RunAs
    exit
}

# Ensure profile directory exists (works for both PowerShell 5.1, 7+, and OneDrive Documents)
$profileFolderPath = Split-Path -Path $PROFILE -Parent
if (-not (Test-Path -LiteralPath $profileFolderPath)) {
    $null = New-Item -Path $profileFolderPath -ItemType Directory -Force
}

$profileUrl = 'https://raw.githubusercontent.com/khad1r/minimal_powershell_setup/main/Microsoft.PowerShell_profile.ps1'
if (Test-Path -LiteralPath $PROFILE -PathType Leaf) {
    $backupPath = Join-Path -Path $profileFolderPath -ChildPath 'oldprofile.ps1'
    Move-Item -LiteralPath $PROFILE -Destination $backupPath -Force
    Write-Host "Backed up existing profile to [$backupPath]."
}

Invoke-RestMethod -Uri $profileUrl -OutFile $PROFILE
Write-Host "Profile installed at [$PROFILE]."

if (-not $ProfileOnly) {
    # Install Scoop if missing
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Invoke-Expression "& {$(Invoke-RestMethod -Uri 'https://get.scoop.sh')} -RunAsAdmin"
        Write-Host 'Scoop has been installed successfully!'
    }
    else {
        Write-Host 'Scoop is already installed.'
    }

    # Install CLI tools via winget (non-interactive)
    $wingetPackages = @(
        'junegunn.fzf'
        'sharkdp.fd'
        'Starship.Starship'
        'Flow-Launcher.Flow-Launcher'
        'Neovim.Neovim'
        'chrisant996.Clink'
        'antonmedv.walk'
    )

    foreach ($pkg in $wingetPackages) {
        winget install --id $pkg --exact --accept-package-agreements --accept-source-agreements
    }
}

# Configure Starship for Clink (ensure directory exists)
$clinkDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'clink'
if (-not (Test-Path -LiteralPath $clinkDir)) {
    $null = New-Item -Path $clinkDir -ItemType Directory -Force
}
"load(io.popen('starship init cmd'):read('*a'))()" | Set-Content -Path (Join-Path -Path $clinkDir -ChildPath 'starship.lua') -Encoding UTF8

# Install PowerShell modules
Install-Module -Name PSFzf -Scope CurrentUser -Force
Install-Module -Name PSReadLine -Scope CurrentUser -Force
Install-Module -Name Terminal-Icons -Scope CurrentUser -Repository PSGallery -Force

# Reload PATH environment variable
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

# Download Starship config (ensure ~/.config exists)
$configDir = Join-Path -Path $HOME -ChildPath '.config'
if (-not (Test-Path -LiteralPath $configDir)) {
    $null = New-Item -Path $configDir -ItemType Directory -Force
}
$themePath = Join-Path -Path $configDir -ChildPath 'starship.toml'
Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/khad1r/minimal_powershell_setup/main/starship.toml' -OutFile $themePath

# Install CaskaydiaCove Nerd Font if missing (use $env:TEMP instead of working directory)
if (-not $ProfileOnly) {
    Write-Host 'Checking Nerd Font...'
    Add-Type -AssemblyName System.Drawing
    $fontFamilies = ([System.Drawing.Text.InstalledFontCollection]::new()).Families.Name

    if ($fontFamilies -notcontains 'CaskaydiaCove NF') {
        $zipPath = Join-Path -Path $env:TEMP -ChildPath 'CascadiaCode.zip'
        $extractPath = Join-Path -Path $env:TEMP -ChildPath 'CascadiaCode'

        Invoke-WebRequest -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip' -OutFile $zipPath
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

        $fontsShellFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
        Get-ChildItem -Path $extractPath -Recurse -Filter '*.ttf' | ForEach-Object {
            if (-not (Test-Path -LiteralPath (Join-Path -Path 'C:\Windows\Fonts' -ChildPath $_.Name))) {
                Write-Host "Installing Font $($_.Name)..."
                $fontsShellFolder.CopyHere($_.FullName, 0x10)
            }
        }

        Remove-Item -Path $extractPath, $zipPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'Setting execution policy...'
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

if (Get-Command wt -ErrorAction SilentlyContinue) {
    Start-Process wt
    exit
}

Write-Host 'Windows Terminal is not installed. Starting PowerShell...'
Start-Process (Get-Process -Id $PID).Path
exit
