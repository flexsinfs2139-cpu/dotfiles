# =========================================================
# POWERSHELL MODULE: UTILITIES
# System tools, network helpers, and shell extensions
# =========================================================

# --- Directory Listing Shortcuts ---
function ll { Get-ChildItem -Force }
function la { Get-ChildItem -Force }

# --- System & Executable Utilities ---
function which {
    param(
        [Parameter(Mandatory)]
        [string]$Command
    )
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd
    } else {
        Write-Error "Command '$Command' not found in system PATH."
    }
}

function mdcd {
    param(
        [Parameter(Mandatory)]
        [string]$Folder
    )
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    Set-Location $Folder
}

function env {
    Write-Host "Opening Windows Environment Variables dialog..." -ForegroundColor Cyan
    rundll32.exe sysdm.cpl,EditEnvironmentVariables
}

# --- Network Utilities ---
function Get-PublicIPInfo {
    <#
    .SYNOPSIS
        Fetches and displays detailed public IP address information.
    .DESCRIPTION
        Calls ipinfo.io to retrieve geolocation, ISP, and network info.
    .EXAMPLE
        Get-PublicIPInfo
    #>
    try {
        Write-Host "Retrieving network info from ipinfo.io..." -ForegroundColor DarkGray
        $data = Invoke-RestMethod -Uri "https://ipinfo.io/json" -Method Get -TimeoutSec 5

        [PSCustomObject]@{
            IP       = $data.ip
            City     = $data.city
            Region   = $data.region
            Country  = $data.country
            ISP      = $data.org
            Location = $data.loc
            TimeZone = $data.timezone
        }
    }
    catch {
        Write-Error "Failed to retrieve network details: $_"
    }
}

function ss {
    param(
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = Read-Host "Enter screenshot name"
    }

    if (-not $Name.EndsWith(".png")) {
        $Name += ".png"
    }

    $devicePath = "/sdcard/$Name"

    adb shell screencap -p $devicePath
    adb pull $devicePath ".\$Name"
    adb shell rm $devicePath

    Write-Host "Screenshot saved: $((Resolve-Path ".\$Name").Path)"
}

function Get-FolderSize {
    param(
        [string]$Path = (Get-Location).Path
    )

    $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum

    [PSCustomObject]@{
        Folder = $Path
        SizeMB = [math]::Round($size / 1MB, 2)
        SizeGB = [math]::Round($size / 1GB, 2)
    }
}
