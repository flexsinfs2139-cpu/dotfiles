# =========================================================
# POWERSHELL MODULE: COMPLETIONS & SHELL UX
# Handles prompts, directory matching, fuzzy search, and predictions
# =========================================================

# ---------------------------------------------------------
# PSReadLine
# ---------------------------------------------------------

if (Get-Module -ListAvailable PSReadLine) {

    Import-Module PSReadLine -ErrorAction SilentlyContinue

    try {
        # Predictions
        Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue

        # History
        Set-PSReadLineOption -HistoryNoDuplicates -ErrorAction SilentlyContinue
        Set-PSReadLineOption -MaximumHistoryCount 5000 -ErrorAction SilentlyContinue

        # Editing
        Set-PSReadLineOption -EditMode Windows -ErrorAction SilentlyContinue

        # Key Bindings
        Set-PSReadLineKeyHandler -Chord Ctrl+Backspace -Function BackwardDeleteWord -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction SilentlyContinue
    }
    catch {
        # Ignore host-specific failures
    }
}

# ---------------------------------------------------------
# Oh My Posh
# ---------------------------------------------------------

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {

    $poshConfig = Join-Path $Global:DotfilesRoot "oh-my-posh\theme.omp.json"

    if (Test-Path $poshConfig) {
        oh-my-posh init pwsh --config $poshConfig | Invoke-Expression
    }
    else {
        Write-Warning "Oh My Posh theme not found: $poshConfig"
    }

}
else {
    Write-Warning "oh-my-posh command not found. Run 'winget install JanDeDobbeleer.OhMyPosh'."
}

# ---------------------------------------------------------
# Zoxide
# ---------------------------------------------------------

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { zoxide init powershell | Out-String })
}
else {
    Write-Warning "zoxide command not found. Run 'winget install ajeetdsouza.zoxide'."
}

# ---------------------------------------------------------
# FZF
# ---------------------------------------------------------

if (Get-Command fzf -ErrorAction SilentlyContinue) {

    try {
        $fzfInit = (& fzf --powershell 2>$null | Out-String)

        if (![string]::IsNullOrWhiteSpace($fzfInit)) {
            Invoke-Expression $fzfInit
        }
    }
    catch {
        # Older versions may not support --powershell
    }

}

# ---------------------------------------------------------
# Terminal Icons
# ---------------------------------------------------------

if (Get-Module -ListAvailable Terminal-Icons) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}
else {
    Write-Warning "Terminal-Icons module not found. Run 'Install-Module Terminal-Icons -Scope AllUsers'."
}