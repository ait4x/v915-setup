<#
.SYNOPSIS
    Downloads this repository and runs setup.ps1.

.DESCRIPTION
    The one-liner entry point, for a machine that has none of the tools yet --
    including git. It fetches a zip rather than cloning, because on a fresh lab
    image git is one of the things we are here to install.

        irm https://raw.githubusercontent.com/ait4x/v915-setup/main/bootstrap.ps1 | iex

    or, to pass arguments:

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
}

# ── Already local? ───────────────────────────────────────────────────────────
# $PSScriptRoot is empty when this text was piped into iex, which is exactly
# how we tell "downloaded and running from a file" from "streamed from the web".

if ($PSScriptRoot) {
    $local = Join-Path $PSScriptRoot 'setup.ps1'
    if (Test-Path -LiteralPath $local) {
        Invoke-Setup $local
        return
    }
}

# ── Fetch ────────────────────────────────────────────────────────────────────

if (-not $Root) {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if (-not $docs) { $docs = Join-Path $env:USERPROFILE 'Documents' }
    $Root = Join-Path $docs 'v915-setup'
}

Write-Host ''
Write-Host "V915 setup bootstrap"
Write-Host "  source : https://github.com/$Repo ($Ref)"
Write-Host "  target : $Root"
Write-Host ''

$git = Get-Command git -ErrorAction SilentlyContinue
if ($git -and (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
    Write-Host 'Updating existing checkout...'
    & $git.Source -C $Root fetch --depth 1 origin $Ref
    & $git.Source -C $Root reset --hard "origin/$Ref"
} else {
    $zip     = Join-Path $env:TEMP "v915-setup-$Ref.zip"
    $staging = Join-Path $env:TEMP "v915-setup-unzip-$([guid]::NewGuid().ToString('N'))"
    $url     = "https://codeload.github.com/$Repo/zip/refs/heads/$Ref"

    Write-Host "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

    Expand-Archive -LiteralPath $zip -DestinationPath $staging -Force
    $extracted = Get-ChildItem -LiteralPath $staging -Directory | Select-Object -First 1
    if (-not $extracted) { throw "Archive from $url did not contain a folder." }

    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    Copy-Item -Path (Join-Path $extracted.FullName '*') -Destination $Root -Recurse -Force

    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
}

$setup = Join-Path $Root 'setup.ps1'
if (-not (Test-Path -LiteralPath $setup)) { throw "setup.ps1 not found in $Root after download." }

# No `exit` here: when this script is streamed into iex, exit would close the
# student's PowerShell window along with the output they need to read.
Invoke-Setup $setup
