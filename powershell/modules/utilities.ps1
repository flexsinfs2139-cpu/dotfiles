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

function rnlog {
    <#
    .SYNOPSIS
        Streams React Native Android logs (ReactNativeJS) as pretty-printed JSON.
    .DESCRIPTION
        Runs 'adb logcat -s ReactNativeJS', strips the logcat metadata
        (timestamp, PID, TID, level, tag) and buffers multi-line JSON until the
        object/array is complete, then re-formats it with ConvertTo-Json.
        Non-JSON log lines are printed as plain text. Malformed entries are
        reported and skipped. Waits for the device to reconnect if logcat stops.
        Press Ctrl+C to stop.
    .EXAMPLE
        rnlog
    .EXAMPLE
        rnlog -Clear
    .EXAMPLE
        rnlog -Raw
    .EXAMPLE
        rnlog -Serial emulator-5554
    .EXAMPLE
        rnlog -NoColor > rn.log
    #>
    [CmdletBinding()]
    param(
        # Clear the existing logcat buffer before starting.
        [switch]$Clear,

        # Show the original ReactNativeJS output without JSON formatting.
        [switch]$Raw,

        # Device serial to use when more than one device is connected.
        [string]$Serial,

        # Max nesting depth for ConvertTo-Json.
        [int]$Depth = 20,

        # Disable JSON syntax colors (e.g. when redirecting to a file).
        [switch]$NoColor
    )

    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
        Write-Error "adb not found in PATH. Install Android SDK Platform-Tools and add its folder to PATH."
        return
    }

    # --- Device check ---
    $devices = @(adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^(\S+)\s+(\S+)' } | ForEach-Object {
        [PSCustomObject]@{ Serial = $Matches[1]; State = $Matches[2] }
    })

    if ($Serial) {
        $device = $devices | Where-Object Serial -eq $Serial
        if (-not $device) {
            Write-Error "Device '$Serial' not found. Connected: $(if ($devices) { $devices.Serial -join ', ' } else { 'none' })"
            return
        }
    }
    elseif ($devices.Count -eq 0) {
        Write-Error "No Android device connected. Connect a device (USB debugging on) or start an emulator."
        return
    }
    elseif ($devices.Count -gt 1 -and -not $env:ANDROID_SERIAL) {
        Write-Error "Multiple devices connected: $($devices.Serial -join ', '). Use: rnlog -Serial <serial>"
        return
    }
    else {
        $device = if ($env:ANDROID_SERIAL) { $devices | Where-Object Serial -eq $env:ANDROID_SERIAL } else { $devices[0] }
    }

    if ($device -and $device.State -ne 'device') {
        Write-Error "Device '$($device.Serial)' is '$($device.State)'. Accept the USB debugging prompt on the device or reconnect it."
        return
    }

    $adbArgs = if ($Serial) { @('-s', $Serial) } else { @() }

    if ($Clear) {
        adb @adbArgs logcat -c
        if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to clear logcat buffer; continuing." }
    }

    # --- JSON buffer state ---
    $buffer = [System.Text.StringBuilder]::new()
    $lineCount = 0
    $depthLevel = 0
    $inString = $false
    $escaped = $false
    $entryHeader = $null

    # --- JSON syntax colors ---
    $useColor = -not $NoColor -and $PSStyle.OutputRendering -ne 'PlainText' -and -not [Console]::IsOutputRedirected
    $jsonColors = @{
        key    = $PSStyle.Foreground.Cyan
        string = $PSStyle.Foreground.Green
        number = $PSStyle.Foreground.Yellow
        bool   = $PSStyle.Foreground.Magenta
        null   = $PSStyle.Foreground.BrightBlack
    }
    $jsonTokens = '(?<key>"(?:[^"\\]|\\.)*")(?=\s*:)|(?<string>"(?:[^"\\]|\\.)*")|(?<number>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(?<bool>\b(?:true|false)\b)|(?<null>\bnull\b)'

    # Wraps each JSON token (key, string, number, bool, null) in its ANSI color.
    $colorize = {
        param([string]$Json)

        if (-not $useColor) { return $Json }

        $Json -replace $jsonTokens, {
            foreach ($name in 'key', 'string', 'number', 'bool', 'null') {
                if ($_.Groups[$name].Success) {
                    return "$($jsonColors[$name])$($_.Value)$($PSStyle.Reset)"
                }
            }
        }
    }

    # Formats the buffered entry (or reports it as malformed) and resets the state.
    # Dot-sourced so the reset applies to the variables above.
    $flush = {
        param([bool]$Incomplete)

        $text = $buffer.ToString().TrimEnd()

        if ($text) {
            try {
                if ($Incomplete) { throw "Incomplete JSON (missing closing bracket)." }

                $parsed = ConvertFrom-Json -InputObject $text -AsHashtable -NoEnumerate -DateKind String -ErrorAction Stop
                & $colorize (ConvertTo-Json -InputObject $parsed -Depth $Depth)
            }
            catch {
                if ($lineCount -eq 1) {
                    # Single line that merely starts with '{' or '[', e.g. "[INFO] ready"
                    $text
                }
                else {
                    Write-Host "rnlog: skipped malformed JSON entry ($lineCount lines): $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host $text -ForegroundColor DarkGray
                }
            }
        }

        [void]$buffer.Clear()
        $depthLevel = 0
        $inString = $false
        $escaped = $false
    }

    # threadtime format: "MM-DD HH:MM:SS.mmm  PID  TID L Tag: message"
    $linePattern = '^(\d\d-\d\d\s+\d\d:\d\d:\d\d\.\d+\s+\d+\s+\d+)\s+[VDIWEFA]\s+ReactNativeJS\s*: ?(.*)$'

    $originalEncoding = [Console]::OutputEncoding

    try {
        # adb emits UTF-8; decode it as such so non-ASCII API data isn't mangled.
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        Write-Host "Listening for ReactNativeJS logs on $($device.Serial)... (Ctrl+C to stop)" -ForegroundColor Cyan

        while ($true) {
            if ($Raw) {
                adb @adbArgs logcat -s ReactNativeJS
            }
            else {
                adb @adbArgs logcat -v threadtime -s ReactNativeJS | ForEach-Object {
                    if ($_ -notmatch $linePattern) { return }

                    $header = $Matches[1]
                    $message = $Matches[2].TrimEnd("`r")

                    # Every line of one console.log call shares the same logcat header.
                    # A new header while still buffering means the previous entry was cut off.
                    if ($buffer.Length -gt 0 -and $header -ne $entryHeader) {
                        . $flush $true
                    }

                    if ($buffer.Length -eq 0) {
                        if ($message -notmatch '^\s*[\[{]') {
                            $message
                            return
                        }
                        $entryHeader = $header
                        $lineCount = 0
                    }

                    [void]$buffer.AppendLine($message)
                    $lineCount++

                    # Track bracket depth, ignoring brackets inside JSON strings.
                    foreach ($ch in $message.ToCharArray()) {
                        if ($inString) {
                            if ($escaped) { $escaped = $false }
                            elseif ($ch -eq '\') { $escaped = $true }
                            elseif ($ch -eq '"') { $inString = $false }
                        }
                        elseif ($ch -eq '"') { $inString = $true }
                        elseif ($ch -eq '{' -or $ch -eq '[') { $depthLevel++ }
                        elseif ($ch -eq '}' -or $ch -eq ']') { $depthLevel-- }
                    }

                    if ($depthLevel -le 0) {
                        . $flush $false
                    }
                }

                if ($buffer.Length -gt 0) {
                    . $flush $true
                }
            }

            # logcat only exits on its own when the device goes away.
            Write-Warning "logcat stopped (device disconnected?). Waiting for device... (Ctrl+C to stop)"
            adb @adbArgs wait-for-device
        }
    }
    finally {
        [Console]::OutputEncoding = $originalEncoding
    }
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
        system awake, and nudges the mouse cursor in all directions every minute
        (see -IntervalSeconds) so the idle timer resets (keeps Teams/Slack "Available" and stops
        policy-enforced screen locks). The cursor returns to where it was.
        Press Ctrl+C to stop.
    .EXAMPLE
        KeepAwake
    .EXAMPLE
        KeepAwake -Minutes 90 -Pixels 20
    #>
    [CmdletBinding()]
    param(
        # How long to stay awake. 0 = until Ctrl+C.
        [int]$Minutes = 0,

        # How far to move the cursor in each direction.
        [int]$Pixels = 1,

        # How often to move the cursor.
        [int]$IntervalSeconds = 60
    )

    if (-not ('KeepAwake.Native' -as [type])) {
        Add-Type -Namespace KeepAwake -Name Native -MemberDefinition @'
[DllImport("kernel32.dll")]
private static extern uint SetThreadExecutionState(uint esFlags);

[DllImport("user32.dll")]
private static extern bool GetCursorPos(out POINT point);

[DllImport("user32.dll")]
private static extern bool SetCursorPos(int x, int y);

[DllImport("user32.dll")]
private static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extraInfo);

private struct POINT { public int X; public int Y; }

// ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
public static void Enable()  { SetThreadExecutionState(0x80000000u | 0x1u | 0x2u); }
public static void Disable() { SetThreadExecutionState(0x80000000u); }

// Move the cursor left, right, up and down, then put it back where it was.
public static void Jiggle(int pixels) {
    POINT p;
    GetCursorPos(out p);

    int[,] offsets = { { -pixels, 0 }, { pixels, 0 }, { 0, -pixels }, { 0, pixels } };
    for (int i = 0; i < offsets.GetLength(0); i++) {
        SetCursorPos(p.X + offsets[i, 0], p.Y + offsets[i, 1]);
        System.Threading.Thread.Sleep(100);
    }
    SetCursorPos(p.X, p.Y);

    // SetCursorPos alone doesn't always count as user input;
    // a zero-distance mouse move does, which resets the idle timer.
    mouse_event(0x0001, 0, 0, 0, UIntPtr.Zero);
}
'@
    }

    $endTime = if ($Minutes -gt 0) { (Get-Date).AddMinutes($Minutes) }

    try {
        [KeepAwake.Native]::Enable()

        while (-not $endTime -or (Get-Date) -lt $endTime) {
            [KeepAwake.Native]::Jiggle($Pixels)
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
    finally {
        [KeepAwake.Native]::Disable()
    }
}
