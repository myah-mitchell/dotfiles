<#
.SYNOPSIS
    Windows-side setup for dotfiles: installs Alacritty, JetBrainsMono Nerd Font (NF/NFM/NFP),
    and creates the Alacritty config symlink pointing into the WSL2 dotfiles repo.
    Called from install.sh on WSL2.

.PARAMETER AlacrittyTarget
    Full Windows path to the alacritty.toml source in the dotfiles repo.
    Example: \\wsl.localhost\Ubuntu-22.04\home\user\GitHub\dotfiles\alacritty\.config\alacritty\alacritty.toml
#>
param(
    [Parameter(Mandatory)]
    [string]$AlacrittyTarget
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

function log  { param([string]$m) Write-Host '[dotfiles]' -ForegroundColor Cyan   -NoNewline; Write-Host " $m" }
function ok   { param([string]$m) Write-Host '[+]'        -ForegroundColor Green  -NoNewline; Write-Host " $m" }
function warn { param([string]$m) Write-Host '[!]'        -ForegroundColor Yellow -NoNewline; Write-Host " $m" }
function err  { param([string]$m) Write-Host '[x]'        -ForegroundColor Red    -NoNewline; Write-Host " $m" }

# --- Alacritty -----------------------------------------------------------
log 'Checking Alacritty...'
# Get-Command is instant; winget list triggers a slow source refresh on every call
$alacrittyCmd = Get-Command alacritty -ErrorAction SilentlyContinue
if ($alacrittyCmd) {
    ok "Alacritty already installed at $($alacrittyCmd.Source)"
} else {
    log 'Installing Alacritty via winget...'
    winget install --id Alacritty.Alacritty --silent --accept-package-agreements --accept-source-agreements 2>&1 |
        Where-Object { $_ -notmatch '^\s*$' }
    ok 'Alacritty installed'
}

# --- JetBrainsMono Nerd Font (NF / NFM / NFP — no NL variants) ----------
log 'Checking JetBrainsMono Nerd Font...'
$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
# Check by file presence; NF files start with JetBrainsMonoNerdFont (not JetBrainsMonoNL)
$existing = Get-ChildItem $fontDir -Filter 'JetBrainsMonoNerdFont*.ttf' -ErrorAction SilentlyContinue
if ($existing) {
    ok "JetBrainsMono Nerd Font already installed ($($existing.Count) files)"
} else {
    log 'Downloading JetBrainsMono Nerd Font (~200 MB)...'
    $zipPath     = "$env:TEMP\JetBrainsMono.zip"
    $extractPath = "$env:TEMP\JetBrainsMonoNF"
    Invoke-WebRequest 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' -OutFile $zipPath
    log 'Extracting and installing font files...'
    Expand-Archive $zipPath -DestinationPath $extractPath -Force
    $regPath = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -ItemType Directory -Force $fontDir | Out-Null
    $count = 0
    # Install NF, NFM, NFP — JetBrainsMonoNerdFont* naturally excludes NL variants
    Get-ChildItem $extractPath -Filter 'JetBrainsMonoNerdFont*.ttf' | ForEach-Object {
        $dest = "$fontDir\$($_.Name)"
        Copy-Item $_.FullName $dest -Force
        New-ItemProperty -Path $regPath -Name "$($_.BaseName) (TrueType)" -Value $dest -Force | Out-Null
        $count++
    }
    ok "JetBrainsMono Nerd Font installed ($count files)"
}

# --- Alacritty config ----------------------------------------------------
log 'Checking Alacritty config...'
$link = "$env:APPDATA\alacritty\alacritty.toml"
New-Item -ItemType Directory -Force "$env:APPDATA\alacritty" | Out-Null
if (Test-Path $link) {
    ok 'Alacritty config already in place'
} else {
    try {
        New-Item -ItemType SymbolicLink -Path $link -Target $AlacrittyTarget -ErrorAction Stop | Out-Null
        ok 'Alacritty config symlink created'
    } catch {
        warn 'Symlink requires Developer Mode -- copying file instead'
        try {
            Copy-Item $AlacrittyTarget $link -Force -ErrorAction Stop
            ok 'Alacritty config copied'
        } catch {
            err "Could not install Alacritty config: $($_.Exception.Message)"
            Write-Host "    Manual: Copy-Item '$AlacrittyTarget' '$link'"
        }
    }
}
