# v915-setup

Machine setup for the tutorials taught in **V915**, PolyU School of Design.

One script, one manifest, one profile per tutorial. It installs git, VS Code, uv
and whatever else a given week needs, checks the things that actually go wrong in
a first class, and can be re-run safely at any point.

Written for the SD5913 week-1 tutorial, but nothing in it is course-specific —
SD2112 or a workshop can add a profile and use the same entry point.

---

## For students

**Download one file and double-click it:**

### ⬇ [setup.bat](https://github.com/ait4x/v915-setup/releases/latest/download/setup.bat)

That is all — nothing needs to be installed first. The file installs **git**, uses it to
clone this repository into `Documents\v915-setup`, and runs the installer from there. You
will be asked for your name and email; use the ones on your GitHub account. It ends with
the course repository cloned into `Documents\pfad`, a Python fetched, the Python extension
installed, and **VS Code open in that folder** — the Run button and `uv run` both work.

Windows may say *"Windows protected your PC"* because the file came from the internet.
**More info → Run anyway.**

If you prefer a terminal, this does exactly the same thing:

```powershell
irm https://raw.githubusercontent.com/ait4x/v915-setup/main/bootstrap.ps1 | iex
```

Already have the folder? Double-click `setup.bat` inside it — it detects that and skips
straight to the install.

**When you finish on a lab machine, double-click `signout.bat`.** V915 computers are
shared: without it, the next person's `git push` goes to *your* GitHub account.

## For the instructor

Survey a lab room before class — reports what is installed, changes nothing:

```powershell
.\setup.ps1 -Check
```

Set a room up ahead of time, including pre-downloading a Python interpreter so
thirty machines are not fetching one at 9am:

```powershell
.\setup.ps1 -Profile base -InstallPython
```

Hand out a repo along with the tools:

```powershell
.\setup.ps1 -Clone sd5913/pfad
```

## Profiles

```powershell
.\setup.ps1 -List
```

| Profile | For |
|---|---|
| `base` | Weeks 1–3: git, VS Code, uv/Python; clones `sd5913/pfad`, fetches a Python, makes a `.venv` with pygame in it, installs the Python extension, opens VS Code in the repo |
| `web` | Deployment weeks — adds Node.js and the GitHub CLI |
| `media` | OpenCV / MediaPipe / video weeks — adds FFmpeg |
| `comfyui` | GPU workstations — no editor, adds qBittorrent and FFmpeg |
| `all` | Everything, for imaging a machine |

## Options

| Flag | Effect |
|---|---|
| `-Profile <name>` | Which profile to install. Default `base`. |
| `-Check` | Report only. Installs nothing. |
| `-List` | Print the profiles and packages, then exit. |
| `-SignOut` | Clear the cached GitHub login and exit. |
| `-Clone <owner/repo\|url>` | Clone a repo once the tools are in place. Profiles carry a default. |
| `-Into <dir>` | Where `-Clone` puts it. Default `Documents`. |
| `-InstallPython` | Also run `uv python install`. Profiles can default this on. |
| `-NoOpen` | Do not open VS Code in the cloned repo at the end. |
| `-SkipIdentity` | Do not touch `git config --global user.*`. |
| `-NonInteractive` | Never prompt. Also set by `V915_NONINTERACTIVE=1`. |

Exit code is `0` when the profile is fully satisfied, `1` when something is still
missing, `2` for a bad profile name — so it can gate a provisioning script.

---

## What it handles that a list of winget commands does not

These are the failures that actually consume tutorial time.

- **Stale `PATH`.** winget installs git, the student types `git`, and the shell —
  started before the install — still has the old `PATH`. The script refreshes
  `PATH` from the registry after every install, so the rest of the run sees the new
  tool, and it says plainly which windows need reopening.
- **No admin rights.** Lab accounts usually do not have them, and a machine-scope
  install stalls on a UAC prompt nobody can answer. Installs are attempted with
  `--scope user` first where a per-user installer exists.
- **winget's exit codes.** It returns large negative numbers for benign outcomes
  such as "already installed". Success is decided by re-locating the executable,
  never by the exit code.
- **Tools installed but not on `PATH`.** Each package carries known install
  locations and, for git, its registry entry, so an existing install is found
  rather than reinstalled.
- **The Microsoft Store `python.exe` stub.** A zero-byte shim, early on `PATH`,
  that opens the Store instead of running Python. It is detected and named, with
  the fix, instead of being discovered mid-exercise.
- **Unset git identity.** Commits with the wrong email get a grey avatar and never
  appear on the contribution graph. Prompted for, once.
- **Shared-machine credentials.** `-SignOut` clears Git Credential Manager, the
  Windows Credential Manager entries and the `gh` login.
- **No winget at all.** On an image without App Installer, every missing package
  prints its download page rather than a stack of red errors.
- **Staying up to date.** The installer arrives as a `git clone`, so every later run is a
  `fetch` rather than a re-download, and a folder left over from an older zip-based run is
  converted into a clone in place — untracked files in it are left alone. A zip fallback
  still exists for a machine where git cannot be installed, but that machine cannot install
  anything else either, so it is a diagnostic path, not a supported one.

## Adding a tutorial

Both manifests are plain PowerShell data files. `setup.ps1` has no per-tool
branches — adding a tool means adding data, not code.

1. Add the tool to `packages.psd1`. The fields are documented at the top of that
   file; `winget search <name>` gives you the id.
2. Add or extend a profile in `profiles.psd1`.
3. Run `.\setup.ps1 -List` to confirm it resolves.

## Layout

```
setup.bat         standalone entry point -- the file students download
bootstrap.ps1     installs git, clones the repo, runs setup.ps1
setup.ps1         the installer
check.bat         double-click wrapper for -Check
signout.bat       double-click wrapper for -SignOut
packages.psd1     one entry per installable tool
profiles.psd1     named sets of packages
lib/Common.ps1    discovery, install, PATH and git helpers
```

### Why the release asset

`raw.githubusercontent.com` serves `.bat` as `text/plain`, so linking the file in the repo
shows a student its source code instead of downloading it. A release asset is served with
`Content-Disposition: attachment` and lands in Downloads as `setup.bat`.

The asset is a snapshot, but it does not go stale: `setup.bat` contains no install logic at
all — only the URL of `bootstrap.ps1`, which is fetched from `main` on every run. Re-attach
it to a new release only if that URL changes.

Requires Windows 10 or 11 with PowerShell 5.1 (the built-in one). winget is used
when present but is not required.
