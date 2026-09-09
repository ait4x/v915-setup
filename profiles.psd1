# Profiles: named sets of packages from packages.psd1, plus what a tutorial
# needs once the tools are in place.
#
# A profile is just data. To add one for a new tutorial, add an entry here --
# no changes to setup.ps1 are needed.
#
#   Packages   Names from packages.psd1, installed in order.
#   Clone      Repository to clone (or pull) after the tools are in, as
#              'owner/repo'. Goes in Documents\<repo> unless -Into is given.
#   Python     $true to run `uv python install` so an interpreter is there
#              before the first `uv run`, rather than downloaded in class.
#   Prefetch   Packages to warm uv's cache with (`uv run --with <pkg>`), so the
#              first script that needs pygame does not stall on the lab uplink.
#   Open       $true to finish by opening VS Code in the cloned repository.
#
# Every one of these is overridable from the command line (-Clone, -InstallPython,
# -NoOpen) and skipped entirely under -Check.
#
#   setup.ps1 -Profile web
#   setup.ps1 -List          # show everything defined below

@{
    base = @{
        Description = 'SD5913 weeks 1-3: git, VS Code, uv/Python; the course repo, open in VS Code.'
        Packages    = @('git', 'vscode', 'uv')
        Clone       = 'sd5913/pfad'
        Python      = $true
        Prefetch    = @('pygame-ce')
        Open        = $true
    }

    web = @{
        Description = 'Deployment weeks: adds Node.js and the GitHub CLI.'
        Packages    = @('git', 'vscode', 'uv', 'node', 'gh')
        Clone       = 'sd5913/pfad'
        Python      = $true
        Open        = $true
    }

    media = @{
        Description = 'OpenCV / MediaPipe / video weeks: adds FFmpeg.'
        Packages    = @('git', 'vscode', 'uv', 'ffmpeg')
        Clone       = 'sd5913/pfad'
        Python      = $true
        Open        = $true
    }

    comfyui = @{
        Description = 'GPU workstations, no editor: model downloads and encoding.'
        Packages    = @('git', 'uv', 'ffmpeg', 'qbittorrent')
    }

    all = @{
        Description = 'Everything in the manifest. For imaging a lab machine.'
        Packages    = @('git', 'vscode', 'uv', 'gh', 'node', 'ffmpeg', 'qbittorrent')
    }
}
