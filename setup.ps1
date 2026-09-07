<#
.SYNOPSIS
    Sets up a Windows machine for an SD5913 tutorial.

.DESCRIPTION
    Reads a profile from profiles.psd1, locates each package it names, installs
    whatever is missing via winget, and prints a summary. Everything tool-
    specific lives in packages.psd1 -- this script has no per-tool branches.

    Safe to re-run. Nothing is installed that is already present, and -Check
    installs nothing at all.

.PARAMETER ProfileName
    Profile from profiles.psd1. Default 'base'.

.PARAMETER Check
    Report what is present or missing and exit. Installs nothing. Use this to
    survey a lab before class.

.PARAMETER Clone
    Repository to clone once the tools are in place. 'owner/repo' or a full URL.

.PARAMETER Into
    Parent directory for -Clone. Default Documents\GitHub.

.PARAMETER InstallPython
    Also run `uv python install`, so a Python interpreter exists before class
    rather than being downloaded by thirty machines at once.

.PARAMETER SignOut
    Clear cached GitHub credentials and exit. Run this at the end of a class on
    a shared machine.

.EXAMPLE
    .\setup.ps1
.EXAMPLE
    .\setup.ps1 -Check
.EXAMPLE
    .\setup.ps1 -Profile web -Clone sd5913/pfad
#>

[CmdletBinding()]
param(
    [Alias('Profile')]
    [string]$ProfileName = 'base',

    [switch]$Check,
    [switch]$List,
    [switch]$SignOut,
    [switch]$NonInteractive,
    [switch]$SkipIdentity,
    [switch]$InstallPython,

    [string]$Clone,
    [string]$Into
)

$ErrorActionPreference = 'Continue'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Root 'lib\Common.ps1')

if ($env:V915_NONINTERACTIVE -eq '1') { $NonInteractive = $true }

$Packages = Import-PowerShellDataFile (Join-Path $Root 'packages.psd1')
$Profiles = Import-PowerShellDataFile (Join-Path $Root 'profiles.psd1')

# ── -List ────────────────────────────────────────────────────────────────────

if ($List) {
    Write-Head 'V915 setup -- available profiles'
    foreach ($key in ($Profiles.Keys | Sort-Object)) {
        $p = $Profiles[$key]
        Write-Host ''
        Write-Host ("  {0,-10} {1}" -f $key, $p.Description)
        Write-Host ("             {0}" -f ($p.Packages -join ', ')) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host '  Packages:'
    foreach ($key in ($Packages.Keys | Sort-Object)) {
        Write-Host ("    {0,-12} {1}" -f $key, $Packages[$key].Why)
    }
    Write-Host ''
    exit 0
}

# ── -SignOut ─────────────────────────────────────────────────────────────────

if ($SignOut) {
    Write-Head 'V915 setup -- clearing cached GitHub sign-in'
    $gitExe = Find-PackageExe $Packages['git']
    Clear-GitHubCredentials -GitExe $gitExe
    exit 0
}

# ── Resolve the profile ──────────────────────────────────────────────────────

if (-not $Profiles.ContainsKey($ProfileName)) {
    Write-Fail "Unknown profile '$ProfileName'. Known: $(($Profiles.Keys | Sort-Object) -join ', ')"
    exit 2
}
$selected = $Profiles[$ProfileName]

$mode = if ($Check) { 'check only, nothing will be installed' } else { 'install' }
Write-Head "V915 setup -- profile '$ProfileName' ($mode)"
Write-Host "  $($selected.Description)"
Write-Host "  Machine : $env:COMPUTERNAME    User: $env:USERNAME"

if (-not $Check -and -not (Test-Winget)) {
    Write-Warn2 'winget (App Installer) is not available on this machine.'
    Write-Hint 'Nothing can be installed automatically. Each missing tool below'
    Write-Hint 'lists a download page -- install those by hand, or install App'
    Write-Hint 'Installer from the Microsoft Store and re-run this script.'
}

# ── Install / check each package ─────────────────────────────────────────────

$results = @()

foreach ($name in $selected.Packages) {
    if (-not $Packages.ContainsKey($name)) {
        Write-Fail "Profile '$ProfileName' names unknown package '$name'."
        $results += [pscustomobject]@{ Package = $name; Status = 'undefined'; Detail = '' }
        continue
    }

    $pkg = $Packages[$name]
    Write-Section "$($pkg.Label)  --  $($pkg.Why)"

    $exe = Find-PackageExe $pkg
    $installed = $false

    if (-not $exe -and -not $Check -and (Test-Winget)) {
        Write-Step 'not found, installing'
        $installed = Install-PackageWithWinget $pkg
        $exe = Find-PackageExe $pkg
    }

    if ($exe) {
        $version = Get-ToolVersion $exe (Get-Field $pkg 'VersionArgs')
        $label = if ($version) { $version } else { $exe }
        if ($installed) { Write-Ok "installed: $label" } else { Write-Ok $label }
        Write-Hint $exe
        $results += [pscustomobject]@{
            Package = $name
            Status  = if ($installed) { 'installed' } else { 'present' }
            Detail  = $exe
        }
    } else {
        if ($Check) { Write-Warn2 'missing' } else { Write-Fail 'could not be installed' }
        Write-Hint "Download: $(Get-Field $pkg 'Url' '(no link recorded)')"
        $results += [pscustomobject]@{ Package = $name; Status = 'missing'; Detail = (Get-Field $pkg 'Url' '') }
    }
}

$gitExe = Find-PackageExe $Packages['git']
$uvExe  = Find-PackageExe $Packages['uv']

# ── Git identity ─────────────────────────────────────────────────────────────

if ($gitExe -and -not $SkipIdentity) {
    Write-Section 'Git identity'
    Set-GitIdentity -GitExe $gitExe -NonInteractive:$NonInteractive -CheckOnly:$Check | Out-Null
}

# ── Python sanity ────────────────────────────────────────────────────────────
# The Microsoft Store ships a zero-byte `python.exe` stub that opens the Store
# instead of running anything. It sits early on PATH and produces the most
# confusing error of week 1, so name it explicitly rather than letting a student
# discover it mid-exercise.

Write-Section 'Python'

$localAppData = [Environment]::GetEnvironmentVariable('LOCALAPPDATA')
$storeStub = if ($localAppData) { Join-Path $localAppData 'Microsoft\WindowsApps\python.exe' } else { $null }
if ($storeStub -and (Test-Path -LiteralPath $storeStub) -and ((Get-Item -LiteralPath $storeStub).Length -eq 0)) {
    Write-Warn2 'The Microsoft Store python.exe stub is on your PATH.'
    Write-Hint 'Typing `python` opens the Store instead of running Python.'
    Write-Hint 'Use `uv run script.py` -- it ignores the stub entirely. To remove it:'
    Write-Hint 'Settings -> Apps -> Advanced app settings -> App execution aliases'
    Write-Hint '-> turn off both "python" entries.'
}

if ($uvExe) {
    $pythons = & $uvExe python list --only-installed 2>$null
    if ($pythons) {
        Write-Ok "uv has $(@($pythons).Count) Python interpreter(s) installed."
    } elseif ($InstallPython -and -not $Check) {
        Write-Step 'uv python install'
        & $uvExe python install
        Write-Ok 'Python installed via uv.'
    } else {
        Write-Warn2 'No Python installed through uv yet.'
        Write-Hint 'That is fine -- `uv run script.py` downloads one on first use.'
        Write-Hint 'To pre-install it now (recommended before a class): setup.ps1 -InstallPython'
    }
}

# ── Optional clone ───────────────────────────────────────────────────────────

if ($Clone -and $gitExe -and -not $Check) {
    Write-Section "Cloning $Clone"

    $url = if ($Clone -match '^[\w.-]+/[\w.-]+$') { "https://github.com/$Clone.git" } else { $Clone }
    if (-not $Into) { $Into = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' }
    New-Item -ItemType Directory -Path $Into -Force | Out-Null

    $leaf = ($url -replace '\.git$', '') -split '/' | Select-Object -Last 1
    $dest = Join-Path $Into $leaf

    if (Test-Path -LiteralPath (Join-Path $dest '.git')) {
        Write-Step "already cloned, pulling: $dest"
        & $gitExe -C $dest pull --ff-only
    } else {
        & $gitExe clone $url $dest
    }

    if (Test-Path -LiteralPath (Join-Path $dest '.git')) {
        Write-Ok $dest
    } else {
        Write-Fail "clone failed: $url"
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────

Write-Head 'Summary'
$results | Format-Table -AutoSize | Out-String | Write-Host

$missing = @($results | Where-Object { $_.Status -ne 'present' -and $_.Status -ne 'installed' })
$fresh   = @($results | Where-Object { $_.Status -eq 'installed' })

if ($missing.Count -gt 0) {
    Write-Fail "$($missing.Count) package(s) still missing: $(($missing.Package) -join ', ')"
    Write-Hint 'Install those from the links above, then re-run this script.'
} else {
    Write-Ok "Profile '$ProfileName' is fully set up."
}

if ($fresh.Count -gt 0) {
    Write-Host ''
    Write-Warn2 'Close and reopen any terminal or VS Code window you already had open.'
    Write-Hint 'They still hold the PATH from before the install -- this is the reason'
    Write-Hint 'for almost every "git is not recognized" after a successful install.'
}

Write-Host ''
Write-Host 'On a shared lab machine, run this before you leave:' -ForegroundColor Cyan
Write-Host '  .\setup.ps1 -SignOut'
Write-Host ''

exit ([int]($missing.Count -gt 0))
