# =========================================================
# POWERSHELL MODULE: ALIASES & SHORTCUTS
# Command wrappers, quick-jump directories, and custom functions
# =========================================================

# --- General Aliases & Shortcuts ---
Set-Alias c code
function ch { code . }

# reload function is defined in the loader or can be run here
function reload {
    . $PROFILE
    Write-Host ""
    Write-Host "PowerShell profile reloaded." -ForegroundColor Green
}
Set-Alias r reload

# --- Directory Shortcuts ---
function desktop { Set-Location "$HOME\Desktop" }
function downloads { Set-Location "$HOME\Downloads" }
function docs { Set-Location "$HOME\Documents" }
function dotfiles { Set-Location "$HOME\.dotfiles" }

# Dynamic projects path
function projects {
    # Resolve ProjectsDrive (defined in profile.ps1 loader)
    $targetPath = if ($null -ne $ProjectsDrive) { $ProjectsDrive } else { "$HOME\Projects" }
    if (!(Test-Path $targetPath)) {
        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    }
    Set-Location $targetPath
}
Set-Alias proj projects

# --- Git Shortcuts (Hardened & Optimized) ---
function gs { git status --short }
function gst { git status }
function ga { git add . }
function gc {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    git commit -m $Message
}
function gp { git push }
function gl { git pull }
function gco {
    param(
        [Parameter(Mandatory)]
        [string]$Branch
    )
    git checkout $Branch
}
function gb { git branch -vv }

# Native Git Clone & CD (Replaces the broken 'git ccl' alias)
function gclcd {
    param(
        [Parameter(Mandatory)]
        [string]$RepoUrl
    )
    $repoName = [System.IO.Path]::GetFileNameWithoutExtension($RepoUrl)
    git clone $RepoUrl
    if ($LASTEXITCODE -eq 0 -and (Test-Path $repoName)) {
        Set-Location $repoName
    }
}
Set-Alias ccl gclcd

# Native Merged Branch Cleanup (Safe for Windows environments)
function git-cleanup {
    Write-Host "Cleaning up merged local branches..." -ForegroundColor Yellow
    $currentBranch = (git branch --show-current).Trim()
    
    # Get all merged branches except current, main, master, develop, dev
    $mergedBranches = git branch --merged | ForEach-Object { $_.Trim() } | Where-Object {
        $_ -and
        $_ -notmatch '^\*' -and
        $_ -ne $currentBranch -and
        $_ -notmatch '^(main|master|develop|dev)$'
    }

    if ($mergedBranches) {
        foreach ($branch in $mergedBranches) {
            Write-Host "  Deleting local branch: $branch" -ForegroundColor DarkGray
            git branch -d $branch
        }
        Write-Host "Local cleanup completed successfully." -ForegroundColor Green
    } else {
        Write-Host "No merged branches to clean up." -ForegroundColor Gray
    }
}

# --- Flutter Shortcuts ---
function fr { flutter run }
function fc { flutter clean }
function fpg { flutter pub get }
function fa { flutter analyze }
