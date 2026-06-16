# =========================================================
# POWERSHELL PROFILE LOADER
# Entry Point: Microsoft.PowerShell_profile.ps1
# =========================================================

# ---------------------------------------------------------
# Startup Timer
# ---------------------------------------------------------

$startupTimer = [System.Diagnostics.Stopwatch]::StartNew()

# ---------------------------------------------------------
# Resolve Dotfiles Root (supports symlinked profile)
# ---------------------------------------------------------

try {
    $profileItem = Get-Item -LiteralPath $PROFILE -ErrorAction Stop

    if ($profileItem.LinkType -and $profileItem.Target) {
        $Global:DotfilesRoot = Split-Path -Parent $profileItem.Target
    }
    else {
        $Global:DotfilesRoot = $PSScriptRoot
    }
}
catch {
    $Global:DotfilesRoot = $PSScriptRoot
}

# ---------------------------------------------------------
# Module Discovery
# ---------------------------------------------------------

$moduleDir = Join-Path $Global:DotfilesRoot "modules"

if (-not (Test-Path $moduleDir)) {
    Write-Warning "Modules directory not found: $moduleDir"
    return
}

# ---------------------------------------------------------
# Load Modules
# ---------------------------------------------------------

$profileModules = @(
    "completions.ps1"
    "aliases.ps1"
    "utilities.ps1"
    "flutter-builder.ps1"
)

foreach ($moduleName in $profileModules) {

    $modulePath = Join-Path $moduleDir $moduleName

    if (Test-Path $modulePath) {
        try {
            . $modulePath
        }
        catch {
            Write-Warning "Failed to load module: $moduleName"
            Write-Warning $_.Exception.Message
        }
    }
    else {
        Write-Warning "Module not found: $modulePath"
    }
}

# ---------------------------------------------------------
# Startup Summary
# ---------------------------------------------------------

$startupTimer.Stop()

Write-Host ""
Write-Host "PowerShell 7 environment loaded in $($startupTimer.ElapsedMilliseconds)ms." -ForegroundColor Green
Write-Host ""
