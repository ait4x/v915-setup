<#
    Shared helpers for the V915 setup scripts. Dot-source this file; it defines
    functions and does nothing on its own.
#>

Set-StrictMode -Version 1.0

# ── Output ───────────────────────────────────────────────────────────────────
# Plain ASCII markers rather than emoji: the lab machines run the legacy
# console host, which renders anything outside cp437 as boxes.

function Write-Head {
    param([string]$Text)
    Write-Host ''
    Write-Host ('=' * 64)
    Write-Host $Text
    Write-Host ('=' * 64)
}

function Write-Section { param([string]$Text) Write-Host ''; Write-Host "$Text" -ForegroundColor Cyan }
function Write-Step    { param([string]$Text) Write-Host "  ... $Text" }
function Write-Ok      { param([string]$Text) Write-Host "  OK   $Text" -ForegroundColor Green }
function Write-Warn2   { param([string]$Text) Write-Host "  WARN $Text" -ForegroundColor Yellow }
function Write-Fail    { param([string]$Text) Write-Host "  FAIL $Text" -ForegroundColor Red }
function Write-Hint    { param([string]$Text) Write-Host "       $Text" -ForegroundColor DarkGray }

# ── Environment ──────────────────────────────────────────────────────────────

function Update-SessionPath {
    <#
        Re-reads Machine + User PATH from the registry into this process.

        This is the single most common failure in a first tutorial: winget
        installs git, the student types `git`, and the shell -- started before
        the install -- still has the old PATH. Calling this after every install
        means the rest of the script sees the new tool without a new terminal.
        It does NOT help terminals the student already had open; tell them to
        reopen those.

        Additive on purpose. Replacing $env:PATH with the registry value would
        drop anything the parent shell put there for this process only, which
        can make a tool found a moment ago disappear mid-run.
    #>
    $current = @()
    if ($env:PATH) { $current = $env:PATH -split ';' | Where-Object { $_ } }

    $fromRegistry = @()
    foreach ($scope in 'Machine', 'User') {
        $value = [Environment]::GetEnvironmentVariable('PATH', $scope)
        if ($value) { $fromRegistry += $value -split ';' | Where-Object { $_ } }
    }

    $seen = @{}
    $merged = @()
    foreach ($entry in @($current + $fromRegistry)) {
        $key = $entry.TrimEnd('\').ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $merged += $entry
    }

    if ($merged.Count) { $env:PATH = $merged -join ';' }
}

function Expand-PathToken {
    param([string]$Path)
    if (-not $Path) { return '' }
    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Get-Field {
    # Hashtables from Import-PowerShellDataFile only carry the keys that were
    # written, and StrictMode makes a missing key throw. This keeps lookups
    # tolerant so manifest entries can omit optional fields.
    param([hashtable]$Table, [string]$Name, $Default = $null)
    if ($Table -and $Table.ContainsKey($Name)) { return $Table[$Name] }
    return $Default
}

# ── Discovery ────────────────────────────────────────────────────────────────

function Find-PackageExe {
    param([hashtable]$Package)

    $names = @()
    $cmd = Get-Field $Package 'Command'
    if ($cmd) { $names += $cmd }
    $names += @(Get-Field $Package 'AltCommands' @())

    foreach ($name in $names) {
        $found = Get-Command $name -ErrorAction SilentlyContinue |
                 Where-Object { $_.CommandType -eq 'Application' } |
                 Select-Object -First 1
        if ($found) { return $found.Source }
    }

    foreach ($entry in @(Get-Field $Package 'RegistryPaths' @())) {
        try {
            $value = (Get-ItemProperty -Path $entry.Key -ErrorAction Stop).($entry.Property)
            if ($value) {
                $candidate = Join-Path $value $entry.Suffix
                if (Test-Path -LiteralPath $candidate) { return $candidate }
            }
        } catch {
            # Key absent or unreadable -- fall through to the next candidate.
        }
    }

    foreach ($raw in @(Get-Field $Package 'KnownPaths' @())) {
        $candidate = Expand-PathToken $raw
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }

    return $null
}

function Get-ToolVersion {
    param([string]$Exe, [string[]]$VersionArgs)
    if (-not $Exe -or -not $VersionArgs) { return '' }
    try {
        $out = & $Exe @VersionArgs 2>$null
        if (-not $out) { return '' }
        return (@($out)[0]).ToString().Trim()
    } catch {
        return ''
    }
}

# ── Installation ─────────────────────────────────────────────────────────────

function Test-Winget {
    return [bool](Get-Command winget -ErrorAction SilentlyContinue)
}

function Install-PackageWithWinget {
    <#
        Installs one package, preferring a per-user install where the manifest
        asks for it -- lab accounts rarely have admin rights, and a machine-scope
        install stalls on a UAC prompt nobody can answer.

        Success is decided by re-locating the executable afterwards, never by
        winget's exit code: winget returns large negative codes for benign
        outcomes such as "already installed" and "no applicable upgrade".
    #>
    param([hashtable]$Package)

    $id = Get-Field $Package 'WingetId'
    if (-not $id) { return $false }
    if (-not (Test-Winget)) { return $false }

    $common = @('--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--silent')
    $attempts = @()
    if ((Get-Field $Package 'Scope') -eq 'user') {
        $attempts += , (@('install', '--id', $id, '-e', '--scope', 'user') + $common)
    }
    $attempts += , (@('install', '--id', $id, '-e') + $common)

    foreach ($wingetArgs in $attempts) {
        Write-Step ("winget " + ($wingetArgs -join ' '))
        & winget @wingetArgs 2>&1 | ForEach-Object { Write-Hint $_ }
        Update-SessionPath
        if (Find-PackageExe $Package) { return $true }
    }

    return $false
}

# ── Git helpers ──────────────────────────────────────────────────────────────

function Get-GitConfig {
    param([string]$GitExe, [string]$Key)
    if (-not $GitExe) { return '' }
    $value = & $GitExe config --global --get $Key 2>$null
    if (-not $value) { return '' }
    return $value.Trim()
}

function Set-GitIdentity {
    <#
        Ensures user.name and user.email are set globally. An unset or wrong
        email is why a student's commits show a grey avatar and never appear on
        their contribution graph -- worth two minutes in class.
    #>
    param([string]$GitExe, [switch]$NonInteractive, [switch]$CheckOnly)

    $name  = Get-GitConfig $GitExe 'user.name'
    $email = Get-GitConfig $GitExe 'user.email'

    if ($name -and $email) {
        Write-Ok "git identity: $name <$email>"
        return $true
    }

    if ($CheckOnly -or $NonInteractive) {
        Write-Warn2 'git identity is not set (user.name / user.email).'
        Write-Hint 'Fix: git config --global user.name "Your Name"'
        Write-Hint '     git config --global user.email "you@example.com"'
        return $false
    }

    Write-Warn2 'git needs to know who you are before you can commit.'
    Write-Hint 'Use the same email as your GitHub account, or GitHub''s noreply'
    Write-Hint 'address (Settings -> Emails) if you would rather not publish it.'

    while (-not $name) { $name = (Read-Host '  Your name').Trim() }
    while (-not $email) { $email = (Read-Host '  Your email').Trim() }

    if ($email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        Write-Warn2 "'$email' does not look like an email address -- setting it anyway."
    }

    & $GitExe config --global user.name  $name  | Out-Null
    & $GitExe config --global user.email $email | Out-Null
    Write-Ok "git identity set: $name <$email>"
    return $true
}

function Clear-GitHubCredentials {
    <#
        Wipes the cached github.com login. V915 machines are shared: without
        this, the next student inherits the previous one's Git Credential
        Manager entry and pushes to their account.
    #>
    param([string]$GitExe)

    if ($GitExe) {
        Write-Step 'Rejecting stored github.com credential (Git Credential Manager)'
        "protocol=https`nhost=github.com`n" | & $GitExe credential reject 2>$null
        "protocol=https`nhost=github.com`nusername=`n" | & $GitExe credential reject 2>$null
    }

    if (Get-Command cmdkey -ErrorAction SilentlyContinue) {
        Write-Step 'Removing github entries from Windows Credential Manager'
        $entries = & cmdkey /list 2>$null |
                   Select-String -Pattern 'Target:\s*(\S*git(hub)?\S*)' -AllMatches |
                   ForEach-Object { $_.Matches[0].Groups[1].Value } |
                   Select-Object -Unique
        foreach ($target in $entries) {
            Write-Hint "cmdkey /delete:$target"
            & cmdkey "/delete:$target" | Out-Null
        }
    }

    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
        Write-Step 'gh auth logout'
        & $gh.Source auth logout --hostname github.com 2>$null | Out-Null
    }

    Write-Ok 'Cached GitHub credentials cleared.'
    Write-Hint 'VS Code keeps its own account session: click the account icon in'
    Write-Hint 'the bottom-left corner and sign out there too. Then close the browser.'
}
