<#
.SYNOPSIS
    Installs git, clones this repository, and runs setup.ps1.

.DESCRIPTION
    The standalone entry point. Normally you do not run it by hand: setup.bat
    downloads and runs it.

    git comes first and the repo is cloned, not downloaded. git is the first
    thing the course installs anyway, so there is nothing to save by avoiding
    it -- and a clone can be brought up to date with a fetch on every later run,
    where an unpacked zip cannot. A zip download survives only as the fallback
    for a machine where git could not be installed at all; the installer will
    not get much done on such a machine either, but it will still run and say
    what is missing.

    The direct routes, if you would rather type than click:

        irm https://raw.githubusercontent.com/ait4x/v915-setup/main/bootstrap.ps1 | iex

        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/ait4x/v915-setup/main/bootstrap.ps1))) -Profile web

    Run from a file next to setup.ps1 it skips all of this and just runs it.

.PARAMETER Ref
    Branch or tag to fetch. Default 'main'.

.PARAMETER Root
    Where to put the clone. Default Documents\v915-setup.
#>

[CmdletBinding()]
param(
    [Alias('Profile')]
    [string]$ProfileName = 'base',

    [switch]$Check,
    [switch]$List,
    [switch]$SignOut,
    [switch]$NonInteractive,
    [switch]$InstallPython,
    [string]$Clone,

    [string]$Ref  = 'main',
    [string]$Root
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # a visible progress bar makes IWR ~10x slower

$Repo    = 'ait4x/v915-setup'
$RepoUrl = "https://github.com/$Repo.git"

# Captured at script scope: inside a function $PSBoundParameters describes that
# function's own call, not this script's.
$BootstrapArgs = $PSBoundParameters

# Empty when this text was piped into iex, set when we are a real file. Decides
# whether it is safe to call exit at the end -- doing so from an iex pipeline
# would close the student's PowerShell window along with the output they need.
$RunningFromFile = [bool]$PSCommandPath
$SetupExitCode   = 0

# PowerShell 5.1 on an un-patched image still defaults to TLS 1.0, which GitHub
# refuses. Setting this is harmless on newer hosts.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ── git ──────────────────────────────────────────────────────────────────────
# A deliberately minimal copy of what packages.psd1 and lib/Common.ps1 do
# properly. This runs before the repo exists, so it cannot use them. Keep it
# short; packages.psd1 remains the authoritative list of install locations.

function Update-SessionPath {
    $entries = @()
    if ($env:PATH) { $entries += $env:PATH -split ';' }
    foreach ($scope in 'Machine', 'User') {
        $value = [Environment]::GetEnvironmentVariable('PATH', $scope)
        if ($value) { $entries += $value -split ';' }
    }

    $seen = @{}
    $merged = @()
    foreach ($entry in $entries) {
        if (-not $entry) { continue }
        $key = $entry.TrimEnd('\').ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $merged += $entry
    }
    if ($merged.Count) { $env:PATH = $merged -join ';' }
}

function Find-Git {
    $cmd = Get-Command git -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandType -eq 'Application' } |
           Select-Object -First 1
    if ($cmd) { return $cmd.Source }

    foreach ($candidate in @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe"
    )) {
        if ((Split-Path $candidate -Parent) -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }

    foreach ($hive in 'HKLM:\SOFTWARE\GitForWindows', 'HKCU:\SOFTWARE\GitForWindows') {
        try {
            $installPath = (Get-ItemProperty -Path $hive -ErrorAction Stop).InstallPath
            if ($installPath) {
                $candidate = Join-Path $installPath 'cmd\git.exe'
                if (Test-Path -LiteralPath $candidate) { return $candidate }
            }
        } catch {
        }
    }

    return $null
}

function Install-Git {
    <#
        Per-user scope first: lab accounts rarely have admin rights, and a
        machine-scope install stalls on a UAC prompt nobody can answer. Success
        is decided by re-locating git.exe, never by winget's exit code -- it
        returns large negative numbers for benign outcomes.
    #>
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning 'winget (App Installer) is not available, so git cannot be installed automatically.'
        return $null
    }

    $tail = @('--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--silent')
    foreach ($scope in @(@('--scope', 'user'), @())) {
        $wingetArgs = @('install', '--id', 'Git.Git', '-e') + $scope + $tail
        Write-Host "  winget $($wingetArgs -join ' ')"
        & winget @wingetArgs 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        Update-SessionPath
        $git = Find-Git
        if ($git) { return $git }
    }

    return $null
}

# ── fetching the repo ────────────────────────────────────────────────────────

function Get-RepoRoot {
    if ($Root) { return $Root }

    # Documents can come back empty when the lab profile uses folder
    # redirection and the network share has not mounted yet. Fall back rather
    # than crashing on Join-Path with a null.
    $base = [Environment]::GetFolderPath('MyDocuments')
    if (-not $base) {
        $profileDir = $env:USERPROFILE
        if (-not $profileDir) { $profileDir = $HOME }
        if ($profileDir) { $base = Join-Path $profileDir 'Documents' }
    }
    if (-not $base) { throw 'Could not determine a home directory. Pass -Root <path>.' }

    return Join-Path $base 'v915-setup'
}

function Get-RepoWithGit {
    param([string]$Destination, [string]$GitExe)

    if (Test-Path -LiteralPath (Join-Path $Destination '.git')) {
        Write-Host "Updating the clone in $Destination"
        & $GitExe -C $Destination remote set-url origin $RepoUrl
    } elseif (Test-Path -LiteralPath $Destination) {
        # Left over from an older zip-based run, or a half-finished download.
        # Convert it into a real clone in place rather than deleting a folder
        # the student may have put something in.
        Write-Host "Converting $Destination into a clone"
        & $GitExe -C $Destination init --quiet
        & $GitExe -C $Destination remote add origin $RepoUrl 2>$null | Out-Null
        & $GitExe -C $Destination remote set-url origin $RepoUrl
    } else {
        Write-Host "Cloning $RepoUrl"
        & $GitExe clone --depth 1 --branch $Ref $RepoUrl $Destination
        if (Test-Path -LiteralPath (Join-Path $Destination '.git')) { return }
        throw "git clone failed for $RepoUrl"
    }

    & $GitExe -C $Destination fetch --depth 1 origin $Ref
    & $GitExe -C $Destination checkout --force -B $Ref "origin/$Ref"
}

function Get-RepoWithZip {
    param([string]$Destination)

    $zip     = Join-Path $env:TEMP "v915-setup-$Ref.zip"
    $staging = Join-Path $env:TEMP "v915-setup-unzip-$([guid]::NewGuid().ToString('N'))"
    $url     = "https://codeload.github.com/$Repo/zip/refs/heads/$Ref"

    Write-Host "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

    Expand-Archive -LiteralPath $zip -DestinationPath $staging -Force
    $extracted = Get-ChildItem -LiteralPath $staging -Directory | Select-Object -First 1
    if (-not $extracted) { throw "Archive from $url did not contain a folder." }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -Path (Join-Path $extracted.FullName '*') -Destination $Destination -Recurse -Force

    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
}

function Invoke-Setup {
    param([string]$SetupPath)

    $forward = @{}
    foreach ($key in $BootstrapArgs.Keys) {
        if ($key -eq 'Ref' -or $key -eq 'Root') { continue }
        $forward[$key] = $BootstrapArgs[$key]
    }

    Write-Host "Running $SetupPath"
    & $SetupPath @forward
    $script:SetupExitCode = $LASTEXITCODE
}

# ── main ─────────────────────────────────────────────────────────────────────

$localSetup = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'setup.ps1' } else { $null }

if ($localSetup -and (Test-Path -LiteralPath $localSetup)) {
    Invoke-Setup $localSetup
} else {
    $repoRoot = Get-RepoRoot

    Write-Host ''
    Write-Host 'V915 setup bootstrap'
    Write-Host "  source : https://github.com/$Repo ($Ref)"
    Write-Host "  target : $repoRoot"
    Write-Host ''

    $git = Find-Git
    if ($git) {
        Write-Host "git already installed: $git"
    } else {
        Write-Host 'git is not installed. Installing it first -- it is the first thing'
        Write-Host 'the course needs anyway, and it is how this installer fetches itself.'
        $git = Install-Git
        if ($git) { Write-Host "git installed: $git" }
    }

    if ($git) {
        try {
            Get-RepoWithGit -Destination $repoRoot -GitExe $git
        } catch {
            Write-Warning "Could not fetch with git: $($_.Exception.Message)"
        }
    }

    $setup = Join-Path $repoRoot 'setup.ps1'

    if (-not (Test-Path -LiteralPath $setup)) {
        if ($git) {
            Write-Warning 'Falling back to a zip download.'
        } else {
            Write-Warning 'git is unavailable, so this run falls back to a zip download.'
            Write-Warning 'The installer will still report what is missing, but it will not be'
            Write-Warning 'able to install anything either. Fix winget first.'
        }
        Get-RepoWithZip -Destination $repoRoot
    }

    if (-not (Test-Path -LiteralPath $setup)) {
        throw "setup.ps1 not found in $repoRoot after fetching."
    }

    Invoke-Setup $setup

    Write-Host ''
    Write-Host "Everything is now in $repoRoot -- run setup.bat from there next time," -ForegroundColor Cyan
    Write-Host 'and signout.bat before you leave a shared machine.' -ForegroundColor Cyan
}

if ($RunningFromFile) { exit $SetupExitCode }
