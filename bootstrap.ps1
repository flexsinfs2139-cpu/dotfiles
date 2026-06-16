# ==============================================================================
# Dotfiles / Configuration Bootstrap Script
# Creates symbolic links for Git and PowerShell configurations
# ==============================================================================

# Clear the screen for a clean start
Clear-Host

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     Dotfiles Configuration Bootstrapper " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# 1. Determine Default Dotfiles Directory Candidate
# ------------------------------------------------------------------------------
$scriptFolder = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$homeDir = $HOME

function IsValidDotfilesDirectory($path) {
    if (-not (Test-Path $path)) { return $false }
    $hasGit = Test-Path (Join-Path $path "git\.gitconfig")
    $hasPS = Test-Path (Join-Path $path "powershell\profile.ps1")
    return $hasGit -and $hasPS
}

$defaultPath = ""
if (IsValidDotfilesDirectory $scriptFolder) {
    $defaultPath = $scriptFolder
} elseif (IsValidDotfilesDirectory (Join-Path $homeDir ".configuration")) {
    $defaultPath = Join-Path $homeDir ".configuration"
} elseif (IsValidDotfilesDirectory (Join-Path $homeDir ".dotfiles")) {
    $defaultPath = Join-Path $homeDir ".dotfiles"
} else {
    $defaultPath = $scriptFolder
}

# ------------------------------------------------------------------------------
# 2. Ask User for Dotfiles Directory
# ------------------------------------------------------------------------------
Write-Host "This script will create symbolic links for your Git and PowerShell profiles." -ForegroundColor Gray
Write-Host "Please specify the path to your dotfiles directory." -ForegroundColor Gray
Write-Host ""

$dotfilesDir = ""
$loopCount = 0
while ($true) {
    $loopCount++
    if ($loopCount -gt 5) {
        Write-Error "Too many failed attempts to select a directory. Aborting."
        exit 1
    }

    $promptPath = if ($defaultPath) { $defaultPath } else { "C:\" }
    
    # Read input from user (checks for redirected/non-interactive stdin)
    $inputPath = Read-Host "Dotfiles Folder Path [$promptPath]"
    
    $nonInteractive = $false
    if ($null -eq $inputPath) {
        Write-Host "Non-interactive environment detected (stdin is null). Using default: $promptPath" -ForegroundColor Gray
        $inputPath = $promptPath
        $nonInteractive = $true
    }

    # Resolve absolute path
    $resolvedPath = ""
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        $resolvedPath = $promptPath
    } else {
        try {
            if ([System.IO.Path]::IsPathRooted($inputPath)) {
                $resolvedPath = [System.IO.Path]::GetFullPath($inputPath)
            } else {
                $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $inputPath))
            }
        } catch {
            $resolvedPath = $inputPath
        }
    }

    if (IsValidDotfilesDirectory $resolvedPath) {
        $dotfilesDir = $resolvedPath
        break
    } else {
        Write-Host ""
        Write-Host "Warning: '$resolvedPath' does not appear to be a valid dotfiles folder." -ForegroundColor Yellow
        Write-Host "A valid folder must contain:" -ForegroundColor Yellow
        Write-Host "  - git\.gitconfig" -ForegroundColor Yellow
        Write-Host "  - powershell\profile.ps1" -ForegroundColor Yellow
        Write-Host ""
        
        if ($nonInteractive) {
            Write-Host "Proceeding with '$resolvedPath' anyway in non-interactive mode." -ForegroundColor Yellow
            $dotfilesDir = $resolvedPath
            break
        }
        
        $confirm = Read-Host "Do you want to use '$resolvedPath' anyway? (y/n)"
        if ($null -eq $confirm) {
            $dotfilesDir = $resolvedPath
            break
        }
        if ($confirm -eq 'y' -or $confirm -eq 'yes') {
            $dotfilesDir = $resolvedPath
            break
        }
    }
}

Write-Host ""
Write-Host "Selected Dotfiles Folder: $dotfilesDir" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# 3. Define Symbolic Links to Create
# ------------------------------------------------------------------------------
$docsPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)

$links = @(
    @{
        Source = Join-Path $dotfilesDir "git\.gitconfig"
        Dest = Join-Path $homeDir ".gitconfig"
        Name = "Git Config (.gitconfig)"
    },
    @{
        Source = Join-Path $dotfilesDir "powershell\profile.ps1"
        Dest = Join-Path $docsPath "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        Name = "Windows PowerShell Profile"
    },
    @{
        Source = Join-Path $dotfilesDir "powershell\profile.ps1"
        Dest = Join-Path $docsPath "PowerShell\Microsoft.PowerShell_profile.ps1"
        Name = "PowerShell 7+ Profile"
    }
)

# ------------------------------------------------------------------------------
# 4. Helper Function: Create Symlink with Conflict Resolution
# ------------------------------------------------------------------------------
function Create-Symlink {
    param (
        [string]$Name,
        [string]$Source,
        [string]$Dest
    )

    Write-Host "Processing: $Name" -ForegroundColor Cyan
    Write-Host "  Source:      $Source" -ForegroundColor Gray
    Write-Host "  Destination: $Dest" -ForegroundColor Gray

    # Verify source exists
    if (-not (Test-Path $Source)) {
        Write-Host "  [SKIP] Source file does not exist: $Source" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    # Ensure parent folder of destination exists
    $destParent = Split-Path -Parent $Dest
    if (-not (Test-Path $destParent)) {
        Write-Host "  Creating parent directory: $destParent" -ForegroundColor Gray
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }

    $shouldCreate = $true

    if (Test-Path $Dest) {
        $item = Get-Item -LiteralPath $Dest -ErrorAction SilentlyContinue
        
        # Check if it is a symbolic link / junction
        if ($item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "Junction") {
            # Normalize target path to compare
            $target = $item.Target
            $resolvedTarget = $target
            if ($null -ne $resolvedTarget) {
                if ($resolvedTarget -is [System.Collections.IEnumerable] -and $resolvedTarget -isnot [string]) {
                    $resolvedTarget = [string]($resolvedTarget | Select-Object -First 1)
                }
                $resolvedTarget = $resolvedTarget.ToString().Trim('{').Trim('}')
            }
            
            $resolvedTarget = [System.IO.Path]::GetFullPath($resolvedTarget)
            $resolvedSource = [System.IO.Path]::GetFullPath($Source)

            if ($resolvedTarget -eq $resolvedSource) {
                Write-Host "  [OK] Already correctly linked to source." -ForegroundColor Green
                Write-Host ""
                return
            } else {
                Write-Host "  [WARN] Destination is currently linked to a different target: $resolvedTarget" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [WARN] Destination already exists as a regular file." -ForegroundColor Yellow
        }

        # Prompt for conflict resolution
        $choice = ""
        while ("backup","overwrite","skip" -notcontains $choice) {
            $choiceInput = Read-Host "  Choose option: [B]ackup & Replace, [O]verwrite, [S]kip"
            
            # If running in non-interactive session and choiceInput is null, default to skip
            if ($null -eq $choiceInput) {
                Write-Host "  Non-interactive environment detected. Skipping link creation to avoid overwriting files." -ForegroundColor Yellow
                $choice = "skip"
                break
            }
            
            switch ($choiceInput.ToLower()) {
                "b" { $choice = "backup" }
                "o" { $choice = "overwrite" }
                "s" { $choice = "skip" }
                "backup" { $choice = "backup" }
                "overwrite" { $choice = "overwrite" }
                "skip" { $choice = "skip" }
            }
        }

        if ($choice -eq "skip") {
            Write-Host "  [SKIP] Skipped link creation." -ForegroundColor Gray
            Write-Host ""
            return
        }

        if ($choice -eq "backup") {
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $leafName = (Split-Path -Leaf $Dest) + "." + $timestamp + ".bak"
            Write-Host "  Backing up existing file to: $destParent\$leafName" -ForegroundColor Gray
            Rename-Item -Path $Dest -NewName $leafName -Force
        } elseif ($choice -eq "overwrite") {
            Write-Host "  Deleting existing file: $Dest" -ForegroundColor Gray
            Remove-Item -Path $Dest -Force
        }
    }

    # Create the symbolic link
    try {
        New-Item -ItemType SymbolicLink -Path $Dest -Value $Source -Force -ErrorAction Stop | Out-Null
        Write-Host "  [SUCCESS] Symbolic link created successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Failed to create symbolic link." -ForegroundColor Red
        Write-Host "  Error message: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "  TIP: On Windows, creating symbolic links requires administrator privileges" -ForegroundColor Yellow
        Write-Host "       or Windows Developer Mode to be enabled." -ForegroundColor Yellow
        Write-Host "       To resolve this:" -ForegroundColor Yellow
        Write-Host "       1. Re-run this script in a PowerShell session launched as Administrator." -ForegroundColor Yellow
        Write-Host "       2. Or enable Developer Mode in Windows Settings (Settings > Update & Security > For developers)." -ForegroundColor Yellow
    }
    Write-Host ""
}

# ------------------------------------------------------------------------------
# 5. Process All Links
# ------------------------------------------------------------------------------
foreach ($link in $links) {
    Create-Symlink -Name $link.Name -Source $link.Source -Dest $link.Dest
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "          Bootstrap Completed!           " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
