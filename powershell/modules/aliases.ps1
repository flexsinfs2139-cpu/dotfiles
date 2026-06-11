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

# --- Flutter Shortcuts ---
function fr { flutter run }
function fc { flutter clean }
function fpg { flutter pub get }
function fa { flutter analyze }
