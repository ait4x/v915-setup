<#
.SYNOPSIS
    Downloads this repository and runs setup.ps1.

.DESCRIPTION
    The standalone entry point, for a machine that has none of the tools yet --
    including git. It fetches a zip rather than cloning, because on a fresh lab
    image git is one of the things we are here to install.

    Normally you do not run this by hand: setup.bat downloads and runs it. The
    direct routes are

        irm https://raw.githubusercontent.com/ait4x/v915-setup/main/bootstrap.ps1 | iex

    or, to pass arguments,

        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/ait4x/v915-setup/main/bootstrap.ps1))) -Profile web

    Run from a file next to setup.ps1 it skips the download and just runs it.

.PARAMETER Ref
    Branch or tag to fetch. Default 'main'.

.PARAMETER Root
    Where to unpack. Default Documents\v915-setup.
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

$Repo = 'ait4x/v915-setup'

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

function Get-RepoRoot {
    if ($Root) { return $Root }

    # Documents can come back empty when the lab profile uses folder
    # redirection and the network share has not mounted yet. Fall back rather
    # than crashing on Join-Path with a null.
    $base = [Environment]::GetFolderPath('MyDocuments')
    if (-not $base) {
        $home = $env:USERPROFILE
        if (-not $home) { $home = $HOME }
        if ($home) { $base = Join-Path $home 'Documents' }
    }
    if (-not $base) { throw 'Could not determine a home directory. Pass -Root <path>.' }

    return Join-Path $base 'v915-setup'
}

function Get-Repo {
    param([string]$Destination)

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git -and (Test-Path -LiteralPath (Join-Path $Destination '.git'))) {
        Write-Host 'Updating existing checkout...'
        & $git.Source -C $Destination fetch --depth 1 origin $Ref
        & $git.Source -C $Destination reset --hard "origin/$Ref"
        return
    }

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

# ── Already local? ───────────────────────────────────────────────────────────

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

    Get-Repo -Destination $repoRoot

    $setup = Join-Path $repoRoot 'setup.ps1'
    if (-not (Test-Path -LiteralPath $setup)) { throw "setup.ps1 not found in $repoRoot after download." }

    Invoke-Setup $setup

    Write-Host ''
    Write-Host "Everything is now in $repoRoot -- run setup.bat from there next time," -ForegroundColor Cyan
    Write-Host 'and signout.bat before you leave a shared machine.' -ForegroundColor Cyan
}

if ($RunningFromFile) { exit $SetupExitCode }
