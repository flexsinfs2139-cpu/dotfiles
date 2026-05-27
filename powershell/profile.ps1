# =========================================================
# POWERSHELL PROFILE
# Developer Environment Setup
# =========================================================

# =========================================================
# OH MY POSH
# =========================================================

oh-my-posh init pwsh --config "$HOME\.dotfiles\oh-my-posh\theme.omp.json" | Invoke-Expression

# =========================================================
# PSREADLINE CONFIGURATION
# Better terminal UX + history management
# =========================================================

Import-Module PSReadLine

# Prediction Settings
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView

# History Settings
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -MaximumHistoryCount 5000

# Edit Mode
Set-PSReadLineOption -EditMode Windows

# Key Bindings
Set-PSReadLineKeyHandler -Chord Ctrl+Backspace -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward


# =========================================================
# TERMINAL UTILITIES
# =========================================================

function reload {
    . $PROFILE

    Write-Host ""
    Write-Host "PowerShell profile reloaded." -ForegroundColor Green
}

Set-Alias r reload

# VS Code
Set-Alias c code

function ch {
    code .
}

# Projects Folder
function projects {
    Set-Location "D:\Projects"
}

Set-Alias proj projects

# Environment Variables
function env {
    rundll32.exe sysdm.cpl,EditEnvironmentVariables
}


# =========================================================
# FLUTTER SHORTCUTS
# =========================================================

function fr {
    flutter run
}

function fc {
    flutter clean
}

function fpg {
    flutter pub get
}

function fa {
    flutter analyze
}


# =========================================================
# GIT SHORTCUTS
# =========================================================

function gs {
    git status
}

function ga {
    git add .
}

function gc {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    git commit -m $Message
}

function gp {
    git push
}

function gl {
    git pull
}

function gco {
    param(
        [Parameter(Mandatory)]
        [string]$Branch
    )

    git checkout $Branch
}

function gb {
    git branch
}


# =========================================================
# DIRECTORY SHORTCUTS
# =========================================================

function desktop {
    Set-Location "$HOME\Desktop"
}

function downloads {
    Set-Location "$HOME\Downloads"
}

function docs {
    Set-Location "$HOME\Documents"
}

function dotfiles {
    Set-Location "$HOME\.dotfiles"
}


# =========================================================
# QUICK UTILITIES
# =========================================================

function ll {
    Get-ChildItem -Force
}

function la {
    Get-ChildItem -Force
}

function which {
    param(
        [Parameter(Mandatory)]
        [string]$Command
    )

    Get-Command $Command
}

function mdcd {
    param(
        [Parameter(Mandatory)]
        [string]$Folder
    )

    New-Item `
        -ItemType Directory `
        -Path $Folder `
        -Force | Out-Null

    Set-Location $Folder
}


# =========================================================
# FLUTTER RELEASE BUILDER
# =========================================================

function flutter-release {

    [CmdletBinding()]
    param (

        [ValidateSet("apk", "aab", "both")]
        [string]$BuildType = "both",

        [string]$Flavor = "",

        [switch]$SplitPerAbi,

        [switch]$Obfuscate,

        [switch]$Clean
    )

    # =====================================================
    # CONFIGURATION
    # =====================================================

    $baseReleasePath = "D:\Projects\Releases"
    $logFile         = "$baseReleasePath\logs\build.log"

    # =====================================================
    # INTERNAL FUNCTIONS
    # =====================================================

    function Ensure-Directory {

        param ([string]$Path)

        if (!(Test-Path $Path)) {
            New-Item -ItemType Directory -Force -Path $Path | Out-Null
        }
    }

    function Write-Log {

        param (
            [string]$Level,
            [string]$Message
        )

        Ensure-Directory (Split-Path $logFile -Parent)

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $line      = "$timestamp | $Level | $Message"

        Add-Content -Path $logFile -Value $line
    }

    function Validate-Artifact {

        param ([string]$Path)

        return (Test-Path $Path) -and ((Get-Item $Path).Length -gt 0)
    }

    function Copy-Artifact {

        param (
            [string]$Source,
            [string]$Destination,
            [string]$Label
        )

        if (!(Validate-Artifact $Source)) {

            $reason = "Artifact not found or empty: $Source"

            Write-Host ""
            Write-Host "  $reason" -ForegroundColor Red
            Write-Log "FAILED" $reason

            return $false
        }

        Ensure-Directory (Split-Path $Destination -Parent)

        Copy-Item -Path $Source -Destination $Destination -Force

        if (!(Validate-Artifact $Destination)) {

            $reason = "Copy validation failed: $Destination"

            Write-Host ""
            Write-Host "  $reason" -ForegroundColor Red
            Write-Log "FAILED" $reason

            return $false
        }

        Write-Log "SUCCESS" "$Label | $Destination"

        return $true
    }

    function Invoke-FlutterBuild {

        param ([string]$ArtifactType)

        $command = "flutter build $ArtifactType --release"

        if (![string]::IsNullOrWhiteSpace($Flavor)) {
            $command += " --flavor $Flavor"
        }

        if ($SplitPerAbi -and $ArtifactType -eq "apk") {
            $command += " --split-per-abi"
        }

        if ($Obfuscate) {

            $debugSymbolPath = "build\debug-symbols\$projectName"
            Ensure-Directory $debugSymbolPath
            $command += " --obfuscate --split-debug-info=$debugSymbolPath"
        }

        Write-Host ""
        Write-Host "  $command" -ForegroundColor DarkGray
        Write-Log "BUILD" $command

        Invoke-Expression $command

        if ($LASTEXITCODE -ne 0) {

            $reason = "$ArtifactType build failed (exit code $LASTEXITCODE)"

            Write-Host ""
            Write-Host "  $reason" -ForegroundColor Red
            Write-Log "FAILED" $reason

            return $false
        }

        return $true
    }

    # =====================================================
    # VALIDATE ENVIRONMENT
    # =====================================================

    if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {

        Write-Host ""
        Write-Host "Flutter SDK not found in PATH." -ForegroundColor Red
        return
    }

    if (!(Test-Path "pubspec.yaml")) {

        Write-Host ""
        Write-Host "pubspec.yaml not found. Not a Flutter project." -ForegroundColor Red
        return
    }

    # =====================================================
    # PARSE pubspec.yaml
    # =====================================================

    $nameLine = Select-String -Path "pubspec.yaml" -Pattern "^name:"

    if (!$nameLine) {

        Write-Host ""
        Write-Host "Project name not found in pubspec.yaml." -ForegroundColor Red
        return
    }

    $projectName = $nameLine.Line.Split(":")[1].Trim()

    $versionLine = Select-String -Path "pubspec.yaml" -Pattern "^version:"

    if (!$versionLine) {

        Write-Host ""
        Write-Host "Version not found in pubspec.yaml." -ForegroundColor Red
        return
    }

    $versionRaw   = $versionLine.Line.Split(":")[1].Trim()
    $versionParts = $versionRaw.Split("+")

    if ($versionParts.Count -lt 2) {

        Write-Host ""
        Write-Host "Invalid version format in pubspec.yaml. Expected: x.y.z+n" -ForegroundColor Red
        return
    }

    $appVersion  = $versionParts[0]
    $buildNumber = $versionParts[1]

    # =====================================================
    # PREPARE RELEASE DIRECTORIES
    # =====================================================

    $timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
    $releaseRoot = "$baseReleasePath\$projectName"

    $apkFolder    = "$releaseRoot\apk"
    $aabFolder    = "$releaseRoot\aab"
    $latestFolder = "$releaseRoot\latest"
    $logsFolder   = "$baseReleasePath\logs"

    Ensure-Directory $apkFolder
    Ensure-Directory $aabFolder
    Ensure-Directory $latestFolder
    Ensure-Directory $logsFolder

    # =====================================================
    # START LOG ENTRY
    # =====================================================

    $startTime = Get-Date

    Add-Content -Path $logFile -Value ("=" * 60)
    Write-Log "START" "$projectName | v$appVersion+$buildNumber"

    # =====================================================
    # HEADER
    # =====================================================

    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host " Flutter Release Builder"             -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Project      : $projectName"
    Write-Host "  Version      : $appVersion"
    Write-Host "  Build Number : $buildNumber"
    Write-Host "  Build Type   : $BuildType"

    if (![string]::IsNullOrWhiteSpace($Flavor)) {
        Write-Host "  Flavor       : $Flavor"
    }

    Write-Host "  Timestamp    : $timestamp"

    # =====================================================
    # BUILD APK
    # =====================================================

    if ($BuildType -eq "apk" -or $BuildType -eq "both") {

        Write-Host ""
        Write-Host "--- Building APK ---" -ForegroundColor Yellow

        if (!(Invoke-FlutterBuild "apk")) { return }

        if ($SplitPerAbi) {

            $splitSourceFolder = "build\app\outputs\flutter-apk"
            $splitApks         = Get-ChildItem -Path $splitSourceFolder -Filter "*.apk"

            foreach ($apkFile in $splitApks) {

                $dest = "$apkFolder\$($apkFile.Name)"
                Copy-Artifact -Source $apkFile.FullName -Destination $dest -Label "APK_CREATED" | Out-Null
            }

            Write-Host ""
            Write-Host "  Split APKs copied successfully." -ForegroundColor Green

        } else {

            $apkSource  = "build\app\outputs\flutter-apk\app-release.apk"
            $apkName    = "$projectName-v$appVersion+$buildNumber-$timestamp.apk"
            $apkArchive = "$apkFolder\$apkName"
            $apkLatest  = "$latestFolder\$projectName-release.apk"

            $ok1 = Copy-Artifact -Source $apkSource -Destination $apkArchive -Label "APK_CREATED"
            $ok2 = Copy-Artifact -Source $apkSource -Destination $apkLatest  -Label "APK_LATEST"

            if (!$ok1 -or !$ok2) { return }

            Write-Host ""
            Write-Host "  APK build completed." -ForegroundColor Green
            Write-Host "  $apkArchive"           -ForegroundColor Cyan
        }
    }

    # =====================================================
    # BUILD AAB
    # =====================================================

    if ($BuildType -eq "aab" -or $BuildType -eq "both") {

        Write-Host ""
        Write-Host "--- Building AAB ---" -ForegroundColor Yellow

        if (!(Invoke-FlutterBuild "appbundle")) { return }

        $aabSource  = "build\app\outputs\bundle\release\app-release.aab"
        $aabName    = "$projectName-v$appVersion+$buildNumber-$timestamp.aab"
        $aabArchive = "$aabFolder\$aabName"
        $aabLatest  = "$latestFolder\$projectName-release.aab"

        $ok1 = Copy-Artifact -Source $aabSource -Destination $aabArchive -Label "AAB_CREATED"
        $ok2 = Copy-Artifact -Source $aabSource -Destination $aabLatest  -Label "AAB_LATEST"

        if (!$ok1 -or !$ok2) { return }

        Write-Host ""
        Write-Host "  AAB build completed." -ForegroundColor Green
        Write-Host "  $aabArchive"           -ForegroundColor Cyan
    }

    # =====================================================
    # OPTIONAL CLEAN
    # =====================================================

    if ($Clean) {

        Write-Host ""
        Write-Host "--- Running flutter clean ---" -ForegroundColor Yellow
        Write-Log "CLEAN" "STARTED"

        flutter clean

        if ($LASTEXITCODE -ne 0) {

            Write-Host ""
            Write-Host "  flutter clean failed." -ForegroundColor Red
            Write-Log "FAILED" "flutter clean exited with code $LASTEXITCODE"
            return
        }

        Write-Host ""
        Write-Host "  Flutter clean completed." -ForegroundColor Green
        Write-Log "CLEAN" "COMPLETED"
    }

    # =====================================================
    # SUMMARY
    # =====================================================

    $duration = [int](((Get-Date) - $startTime).TotalSeconds)

    Write-Log "END" "DURATION=$($duration)s"

    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host " Release Completed Successfully"      -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Release Path : " -NoNewline
    Write-Host $releaseRoot        -ForegroundColor Cyan
    Write-Host "  Log File     : " -NoNewline
    Write-Host $logFile            -ForegroundColor Cyan
    Write-Host "  Duration     : $($duration)s"

    # =====================================================
    # OPEN FOLDERS
    # =====================================================

    if (Test-Path $releaseRoot)    { Start-Process explorer.exe $releaseRoot }
    if (Test-Path $baseReleasePath) { Start-Process explorer.exe $baseReleasePath }

    Write-Host ""
}


# =========================================================
# STARTUP MESSAGE
# =========================================================

Write-Host ""
Write-Host "PowerShell 7 Loaded" -ForegroundColor Green
Write-Host "Projects : D:\Projects" -ForegroundColor Cyan
Write-Host ""

