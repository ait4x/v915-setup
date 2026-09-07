# Package manifest for the V915 lab setup script.
#
# Each entry describes one installable tool. Everything the installer knows
# about a tool lives here -- setup.ps1 contains no per-tool special cases.
#
#   Label        Human name, shown in output.
#   Why          One line explaining why the course needs it.
#   WingetId     Exact winget package id (`winget search <name>` to confirm).
#   Url          Manual download page, used when winget is unavailable.
#   Command      Name to look for on PATH.
#   AltCommands  Other names worth trying.
#   Scope        'user' asks winget for a per-user install first. Lab accounts
#                usually lack admin rights, so prefer this where it exists.
#   VersionArgs  Arguments that make the tool print its version.
#   KnownPaths   Fallback locations, searched when PATH lookup fails.
#                %VAR% tokens are expanded at runtime.
#   RegistryPaths  Registry-recorded install locations: Key + Property + Suffix.

@{
    git = @{
        Label       = 'Git for Windows'
        Why         = 'Version control. Used in every week of the course.'
        WingetId    = 'Git.Git'
        Url         = 'https://git-scm.com/download/win'
        Command     = 'git'
        Scope       = 'user'
        VersionArgs = @('--version')
        KnownPaths  = @(
            '%LOCALAPPDATA%\Microsoft\WinGet\Links\git.exe',
            '%LOCALAPPDATA%\Programs\Git\cmd\git.exe',
            '%LOCALAPPDATA%\Programs\Git\bin\git.exe',
            '%ProgramFiles%\Git\cmd\git.exe',
            '%ProgramFiles(x86)%\Git\cmd\git.exe'
        )
        RegistryPaths = @(
            @{ Key = 'HKLM:\SOFTWARE\GitForWindows'; Property = 'InstallPath'; Suffix = 'cmd\git.exe' },
            @{ Key = 'HKCU:\SOFTWARE\GitForWindows'; Property = 'InstallPath'; Suffix = 'cmd\git.exe' }
        )
    }

    vscode = @{
        Label       = 'Visual Studio Code'
        Why         = 'The editor the tutorials are demonstrated in.'
        WingetId    = 'Microsoft.VisualStudioCode'
        Url         = 'https://code.visualstudio.com/download'
        Command     = 'code'
        Scope       = 'user'
        VersionArgs = @('--version')
        KnownPaths  = @(
            '%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd',
            '%ProgramFiles%\Microsoft VS Code\bin\code.cmd'
        )
    }

    uv = @{
        Label       = 'uv (Python toolchain)'
        Why         = 'Installs Python and runs scripts. Replaces pip and venv.'
        WingetId    = 'astral-sh.uv'
        Url         = 'https://docs.astral.sh/uv/getting-started/installation/'
        Command     = 'uv'
        Scope       = 'user'
        VersionArgs = @('--version')
        KnownPaths  = @(
            '%LOCALAPPDATA%\Microsoft\WinGet\Links\uv.exe',
            '%USERPROFILE%\.local\bin\uv.exe',
            '%LOCALAPPDATA%\Programs\uv\uv.exe'
        )
    }

    gh = @{
        Label       = 'GitHub CLI'
        Why         = 'Browser-based sign-in for pushing. Avoids pasting tokens.'
        WingetId    = 'GitHub.cli'
        Url         = 'https://cli.github.com/'
        Command     = 'gh'
        Scope       = 'user'
        VersionArgs = @('--version')
        KnownPaths  = @(
            '%LOCALAPPDATA%\Microsoft\WinGet\Links\gh.exe',
            '%ProgramFiles%\GitHub CLI\gh.exe'
        )
    }

    node = @{
        Label       = 'Node.js LTS'
        Why         = 'Cloudflare Workers, Capacitor and the deployment weeks.'
        WingetId    = 'OpenJS.NodeJS.LTS'
        Url         = 'https://nodejs.org/en/download'
        Command     = 'node'
        VersionArgs = @('--version')
        KnownPaths  = @(
            '%ProgramFiles%\nodejs\node.exe',
            '%LOCALAPPDATA%\Programs\nodejs\node.exe'
        )
    }

    ffmpeg = @{
        Label       = 'FFmpeg'
        Why         = 'Video and audio encoding for the OpenCV and video weeks.'
        WingetId    = 'Gyan.FFmpeg'
        Url         = 'https://www.gyan.dev/ffmpeg/builds/'
        Command     = 'ffmpeg'
        VersionArgs = @('-version')
        KnownPaths  = @(
            '%LOCALAPPDATA%\Microsoft\WinGet\Links\ffmpeg.exe'
        )
    }

    qbittorrent = @{
        Label       = 'qBittorrent'
        Why         = 'Fetches large model weights on the GPU workstations.'
        WingetId    = 'qBittorrent.qBittorrent'
        Url         = 'https://www.qbittorrent.org/download'
        Command     = 'qbittorrent'
        KnownPaths  = @(
            '%ProgramFiles%\qBittorrent\qbittorrent.exe',
            '%ProgramFiles(x86)%\qBittorrent\qbittorrent.exe'
        )
    }
}
