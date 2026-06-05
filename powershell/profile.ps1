# =========================================================
# POWERSHELL PROFILE LOADER
# Entry point: Sourced by $PROFILE to load modular shell configs
# =========================================================

# Start stopwatch to monitor startup latency
$startupTimer = [System.Diagnostics.Stopwatch]::StartNew()

# --- Dynamic Projects Drive Detection ---
# Enterprise fallback logic to support secondary developer workstations
$ProjectsDrive = "D:\Projects"
if (!(Test-Path $ProjectsDrive)) {
    $ProjectsDrive = "$HOME\Projects"
}

# --- Module Path Resolution ---
# 1. Checks folder relative to currently executing script path (resolving symlinks/junctions if applicable)
# 2. Falls back to default $HOME\.dotfiles location (good for copied profile files)
$moduleDir = $null

$scriptPath = $MyInvocation.MyCommand.Path
if ($scriptPath) {
    # Resolve symbolic links/junctions to locate the actual target file (PowerShell 5.0+)
    try {
        $item = Get-Item -LiteralPath $scriptPath -ErrorAction SilentlyContinue
        if ($item -and $item.Target) {
            $scriptPath = $item.Target
        }
    } catch {}

    $scriptDir = Split-Path -Parent $scriptPath
    $localModules = Join-Path $scriptDir "modules"
    # Ensure it is the correct modules folder by checking if aliases.ps1 exists in it
    if ((Test-Path $localModules) -and (Test-Path (Join-Path $localModules "aliases.ps1"))) {
        $moduleDir = $localModules
    }
}

if ($null -eq $moduleDir) {
    $fallbackModules = "$HOME\.dotfiles\powershell\modules"
    if (Test-Path $fallbackModules) {
        $moduleDir = $fallbackModules
    }
}

# --- Load Sub-Modules ---
if ($null -ne $moduleDir) {
    $profileModules = @(
        "completions.ps1",
        "aliases.ps1",
        "utilities.ps1",
        "flutter-builder.ps1"
    )

    foreach ($moduleName in $profileModules) {
        $modulePath = Join-Path $moduleDir $moduleName
        if (Test-Path $modulePath) {
            . $modulePath
        } else {
            Write-Warning "Could not find profile sub-module: $modulePath"
        }
    }
} else {
    Write-Warning "Could not locate PowerShell profile modules folder (checked script-local and fallback '$HOME\.dotfiles\powershell\modules')."
}

# --- Finish Timer & Show Welcome Message ---
$startupTimer.Stop()
$loadTimeMs = $startupTimer.Elapsed.TotalMilliseconds

Write-Host ""
Write-Host "PowerShell 7 environment loaded in $($loadTimeMs.ToString('F0'))ms." -ForegroundColor Green
Write-Host "Projects workspace : " -NoNewline
Write-Host $ProjectsDrive -ForegroundColor Cyan
if (!(Test-Path $ProjectsDrive)) {
    Write-Warning "Projects directory does not exist yet. Running 'proj' will create it."
}
Write-Host ""
