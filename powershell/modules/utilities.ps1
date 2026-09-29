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


function New-ProjectName {
    param(
        [string]$ProjectName
    )

    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        $ProjectName = Read-Host "Enter project name"
    }

    $pascalCase = (($ProjectName -split '[-_\s]') | ForEach-Object {
        if ($_ -and $_.Length -gt 0) {
            $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower()
        }
    }) -join ''

    $result = "$pascalCase-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    $result | Set-Clipboard

    Write-Host "Copied to clipboard: $result" -ForegroundColor Green
    return $result
}

function GetDateStamp {
    param(
        [string]$Prefix
    )

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"

    $result = if ([string]::IsNullOrWhiteSpace($Prefix)) {
        $stamp
    } else {
        "$($Prefix.ToUpperInvariant())_$stamp"
    }

    # Copy to clipboard
    $result | Set-Clipboard

    return $result
}

function Find-CodeUsage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Position = 1)]
        [string]$Path
    )

    # Ask for a folder if none was provided.
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Add-Type -AssemblyName System.Windows.Forms

        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = "Select the folder to search"
        $dialog.ShowNewFolderButton = $false

        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            Write-Warning "Search cancelled."
            return
        }

        $Path = $dialog.SelectedPath
    }

    if (-not (Test-Path $Path -PathType Container)) {
        Write-Error "Folder not found: $Path"
        return
    }

    $pattern = [regex]::Escape($Name) + '\s*\('

    Write-Host ""
    Write-Host "Searching for '$Name' in:" -ForegroundColor Cyan
    Write-Host "  $Path" -ForegroundColor Yellow
    Write-Host ("=" * 80)

    $results = foreach ($file in Get-ChildItem -Path $Path -Recurse -File) {
        $lineNumber = 0

        Get-Content $file.FullName | ForEach-Object {
            $lineNumber++

            if ($_ -match $pattern) {
                [PSCustomObject]@{
                    File = $file.FullName
                    Line = $lineNumber
                    Code = $_.Trim()
                }
            }
        }
    }

    if ($results) {
        $results | Format-Table -AutoSize

        Write-Host ""
        Write-Host "Found $($results.Count) match(es)." -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "No matches found." -ForegroundColor Yellow
    }

    return $results
}

function KeepAwake {
    <#
    .SYNOPSIS
        Keeps the screen on and prevents the PC from sleeping.
    .DESCRIPTION
        Uses the Windows SetThreadExecutionState API to keep the display and
        system awake while running. Use -SimulateInput to also send a harmless
        F15 keypress, which resets the user idle timer (keeps Teams/Slack
        "Available" and stops policy-enforced screen locks).
        Press Ctrl+C to stop.
    .EXAMPLE
        KeepAwake
    .EXAMPLE
        KeepAwake -Minutes 90 -SimulateInput
    #>
    [CmdletBinding()]
    param(
        # How long to stay awake. 0 = until Ctrl+C.
        [int]$Minutes = 0,

        # Send an F15 keypress each interval to reset the idle timer.
        [switch]$SimulateInput,

        [int]$IntervalSeconds = 60
    )

    if (-not ('KeepAwake.Power' -as [type])) {
        Add-Type -Namespace KeepAwake -Name Power -MemberDefinition @'
[DllImport("kernel32.dll")]
private static extern uint SetThreadExecutionState(uint esFlags);

// ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
public static void Enable()  { SetThreadExecutionState(0x80000000u | 0x1u | 0x2u); }
public static void Disable() { SetThreadExecutionState(0x80000000u); }
'@
    }

    $shell   = if ($SimulateInput) { New-Object -ComObject WScript.Shell }
    $endTime = if ($Minutes -gt 0) { (Get-Date).AddMinutes($Minutes) }

    try {
        [KeepAwake.Power]::Enable()

        while (-not $endTime -or (Get-Date) -lt $endTime) {
            if ($shell) { $shell.SendKeys('{F15}') }
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
    finally {
        [KeepAwake.Power]::Disable()
    }
}
