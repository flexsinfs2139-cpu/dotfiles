# =========================================================
# POWERSHELL MODULE: COMPLETIONS & SHELL UX
# Handles prompts, directory matching, fuzzy search, and predictions
# =========================================================

# --- PSReadLine Config ---
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue

    try {
        # Prediction Settings (may fail in redirected/non-interactive environments)
        Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue

        # History Settings
        Set-PSReadLineOption -HistoryNoDuplicates -ErrorAction SilentlyContinue
        Set-PSReadLineOption -MaximumHistoryCount 5000 -ErrorAction SilentlyContinue

        # Edit Mode
        Set-PSReadLineOption -EditMode Windows -ErrorAction SilentlyContinue

        # Key Bindings
        Set-PSReadLineKeyHandler -Chord Ctrl+Backspace -Function BackwardDeleteWord -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction SilentlyContinue
    } catch {
        # Catch and suppress console Host exceptions when running in non-interactive shells
    }
}

# --- Prompt Initialization (Oh My Posh) ---
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    # Resolve config path relative to the profile folder to keep it relocatable
    $poshConfig = Join-Path (Split-Path -Parent $PSScriptRoot) "oh-my-posh\theme.omp.json"
    if (Test-Path $poshConfig) {
        oh-my-posh init pwsh --config $poshConfig | Invoke-Expression
    } else {
        # Fallback to default path
        oh-my-posh init pwsh --config "$HOME\.dotfiles\oh-my-posh\theme.omp.json" | Invoke-Expression
    }
} else {
    Write-Warning "oh-my-posh command not found. Run 'winget install JanDeDobbeleer.OhMyPosh'."
}

# --- Directory Navigation (Zoxide) ---
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
} else {
    Write-Warning "zoxide command not found. Run 'winget install ajeetdsouza.zoxide'."
}

# --- Fuzzy Finder (FZF) ---
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    # Guard against older FZF versions that do not support the --powershell flag
    try {
        $fzfInit = (& fzf --powershell 2>$null | Out-String)
        if (![string]::IsNullOrWhiteSpace($fzfInit)) {
            Invoke-Expression $fzfInit
        }
    } catch {
        # Suppress any output errors for older fzf versions
    }
}

# --- Terminal Icons ---
if (Get-Module -ListAvailable Terminal-Icons) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
} else {
    Write-Warning "Terminal-Icons module not found. Run 'Install-Module Terminal-Icons -Scope CurrentUser'."
}
