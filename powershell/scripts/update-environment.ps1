# =========================================================
# SILENT AUTO-UPDATE MAINTENANCE SCRIPT
# Runs daily via Task Scheduler to maintain dotfiles and CLI tools
# =========================================================

# --- 1. Pull Git Dotfiles Updates ---
$dotfilesDir = Join-Path $HOME ".dotfiles"
if (Test-Path $dotfilesDir) {
    try {
        Set-Location $dotfilesDir
        git pull 2>&1 | Out-Null
    } catch {
        # Suppress errors for silent execution
    }
}

# --- 2. Update PowerShell Modules ---
try {
    # Update known environment modules
    $modulesToUpdate = @("Terminal-Icons", "PSReadLine")
    foreach ($mod in $modulesToUpdate) {
        if (Get-Module -ListAvailable $mod) {
            Update-Module -Name $mod -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    # Suppress errors for silent execution
}

# --- 3. Upgrade Command Line Tools (Winget) ---
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $packages = @(
        "Microsoft.PowerShell",
        "JanDeDobbeleer.OhMyPosh",
        "ajeetdsouza.zoxide",
        "junegunn.fzf"
    )

    foreach ($pkg in $packages) {
        try {
            # Run winget upgrade silently
            winget upgrade --id $pkg --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        } catch {
            # Suppress errors for silent execution
        }
    }
}
