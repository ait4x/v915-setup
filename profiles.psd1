# Profiles: named sets of packages from packages.psd1.
#
# A profile is just a list. To add one for a new tutorial, add an entry here --
# no changes to setup.ps1 are needed.
#
#   setup.ps1 -Profile web
#   setup.ps1 -List          # show everything defined below

@{
    base = @{
        Description = 'Week 1 baseline: git, VS Code, uv/Python.'
        Packages    = @('git', 'vscode', 'uv')
    }

    web = @{
        Description = 'Deployment weeks: adds Node.js and the GitHub CLI.'
        Packages    = @('git', 'vscode', 'uv', 'node', 'gh')
    }

    media = @{
        Description = 'OpenCV / MediaPipe / video weeks: adds FFmpeg.'
        Packages    = @('git', 'vscode', 'uv', 'ffmpeg')
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
