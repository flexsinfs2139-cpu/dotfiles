# =========================================================
# POWERSHELL MODULE: FLUTTER RELEASE BUILDER
# Automates APK/AAB building, version parsing, and release management
# =========================================================

function flutter-release {
    <#
    .SYNOPSIS
        Builds, tags, and archives Flutter release binaries (APK/AAB).
    .DESCRIPTION
        Parses pubspec.yaml to extract project name and version, triggers
        appropriate flutter build commands, handles flavor outputs, and copies
        the artifacts to a dedicated release archive folder.
    .PARAMETER BuildType
        Specify whether to build 'apk', 'aab', or 'both' (default).
    .PARAMETER Flavor
        Specify the build flavor (e.g. dev, staging, prod).
    .PARAMETER SplitPerAbi
        Split APKs per ABI (architecture). Only applies to APK builds.
    .PARAMETER Obfuscate
        Enable code obfuscation and split debug symbols.
    .PARAMETER Clean
        Triggers a flutter clean after successful builds.
    .EXAMPLE
        flutter-release -BuildType apk -Flavor staging -Obfuscate
    #>
    [CmdletBinding()]
    param (
        [ValidateSet("apk", "aab", "both")]
        [string]$BuildType = "both",

        [string]$Flavor = "",

        [switch]$SplitPerAbi,

        [switch]$Obfuscate,

        [switch]$Clean
    )

    # --- Release Storage Path ---
    $targetDrive = if ($null -ne $ProjectsDrive) { $ProjectsDrive } else { "$HOME\Projects" }
    $baseReleasePath = Join-Path $targetDrive "Releases"
    $logFile         = Join-Path $baseReleasePath "logs\build.log"

    # --- Helper Functions ---
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
            Write-Host "  $reason" -ForegroundColor Red
            Write-Log "FAILED" $reason
            return $false
        }
        Ensure-Directory (Split-Path $Destination -Parent)
        Copy-Item -Path $Source -Destination $Destination -Force
        if (!(Validate-Artifact $Destination)) {
            $reason = "Copy validation failed: $Destination"
            Write-Host "  $reason" -ForegroundColor Red
            Write-Log "FAILED" $reason
            return $false
        }
        Write-Log "SUCCESS" "$Label | $Destination"
        return $true
    }

    function Invoke-FlutterBuild {
        param (
            [string]$ArtifactType,
            [string]$ProjName
        )
        # Use native call list where possible, or clean command string
        $command = "flutter build $ArtifactType --release"
        if (![string]::IsNullOrWhiteSpace($Flavor)) {
            $command += " --flavor $Flavor"
        }
        if ($SplitPerAbi -and $ArtifactType -eq "apk") {
            $command += " --split-per-abi"
        }
        if ($Obfuscate) {
            $debugSymbolPath = "build\debug-symbols\$ProjName"
            Ensure-Directory $debugSymbolPath
            $command += " --obfuscate --split-debug-info=$debugSymbolPath"
        }

        Write-Host "  Executing: $command" -ForegroundColor DarkGray
        Write-Log "BUILD" $command
        
        Invoke-Expression $command

        if ($LASTEXITCODE -ne 0) {
            $reason = "$ArtifactType build failed (exit code $LASTEXITCODE)"
            Write-Host "  $reason" -ForegroundColor Red
            Write-Log "FAILED" $reason
            return $false
        }
        return $true
    }

    # --- Validate Environment ---
    if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
        Write-Host "Flutter SDK not found in PATH." -ForegroundColor Red
        return
    }
    if (!(Test-Path "pubspec.yaml")) {
        Write-Host "pubspec.yaml not found. Run this from a Flutter project directory." -ForegroundColor Red
        return
    }

    # --- Parse pubspec.yaml ---
    $nameLine = Select-String -Path "pubspec.yaml" -Pattern "^name:"
    if (!$nameLine) {
        Write-Host "Project name not found in pubspec.yaml." -ForegroundColor Red
        return
    }
    $projectName = $nameLine.Line.Split(":")[1].Trim()

    $versionLine = Select-String -Path "pubspec.yaml" -Pattern "^version:"
    if (!$versionLine) {
        Write-Host "Version not found in pubspec.yaml." -ForegroundColor Red
        return
    }
    $versionRaw   = $versionLine.Line.Split(":")[1].Trim()
    $versionParts = $versionRaw.Split("+")
    if ($versionParts.Count -lt 2) {
        Write-Host "Invalid version format in pubspec.yaml. Expected: x.y.z+n" -ForegroundColor Red
        return
    }
    $appVersion  = $versionParts[0]
    $buildNumber = $versionParts[1]

    # --- Setup Directories ---
    $timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
    $releaseRoot = Join-Path $baseReleasePath $projectName
    $apkFolder    = Join-Path $releaseRoot "apk"
    $aabFolder    = Join-Path $releaseRoot "aab"
    $latestFolder = Join-Path $releaseRoot "latest"

    Ensure-Directory $apkFolder
    Ensure-Directory $aabFolder
    Ensure-Directory $latestFolder

    $startTime = Get-Date
    Add-Content -Path $logFile -Value ("=" * 60)
    Write-Log "START" "$projectName | v$appVersion+$buildNumber"

    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host " Flutter Release Builder"             -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  Project      : $projectName"
    Write-Host "  Version      : $appVersion"
    Write-Host "  Build Number : $buildNumber"
    Write-Host "  Build Type   : $BuildType"
    if (![string]::IsNullOrWhiteSpace($Flavor)) { Write-Host "  Flavor       : $Flavor" }
    Write-Host "  Timestamp    : $timestamp"

    # --- Build APK ---
    if ($BuildType -eq "apk" -or $BuildType -eq "both") {
        Write-Host "--- Building APK ---" -ForegroundColor Yellow
        if (!(Invoke-FlutterBuild -ArtifactType "apk" -ProjName $projectName)) { return }

        # Resolve output APK source path (flavor vs default)
        $apkSource = "build\app\outputs\flutter-apk\app-release.apk"
        if (![string]::IsNullOrWhiteSpace($Flavor)) {
            $apkSource = "build\app\outputs\flutter-apk\app-$Flavor-release.apk"
        }

        if ($SplitPerAbi) {
            $splitSourceFolder = "build\app\outputs\flutter-apk"
            # Match APKs that have the flavor name (or any apk if flavor is blank)
            $splitApks = Get-ChildItem -Path $splitSourceFolder -Filter "*.apk" | Where-Object { 
                $null -eq $_.Name -or $_.Name -match $Flavor 
            }
            foreach ($apkFile in $splitApks) {
                $dest = Join-Path $apkFolder $apkFile.Name
                Copy-Artifact -Source $apkFile.FullName -Destination $dest -Label "APK_SPLIT_CREATED" | Out-Null
            }
            Write-Host "  Split APKs copied successfully." -ForegroundColor Green
        } else {
            $apkName    = "$projectName-v$appVersion+$buildNumber-$timestamp.apk"
            $apkArchive = Join-Path $apkFolder $apkName
            $apkLatest  = Join-Path $latestFolder "$projectName-release.apk"

            $ok1 = Copy-Artifact -Source $apkSource -Destination $apkArchive -Label "APK_CREATED"
            $ok2 = Copy-Artifact -Source $apkSource -Destination $apkLatest  -Label "APK_LATEST"
            if (!$ok1 -or !$ok2) { return }
            Write-Host "  APK build completed." -ForegroundColor Green
            Write-Host "  Archived: $apkArchive" -ForegroundColor Cyan
        }
    }

    # --- Build AAB ---
    if ($BuildType -eq "aab" -or $BuildType -eq "both") {
        Write-Host "--- Building AAB ---" -ForegroundColor Yellow
        if (!(Invoke-FlutterBuild -ArtifactType "appbundle" -ProjName $projectName)) { return }

        # Resolve output AAB source path (flavor vs default)
        $aabSource = "build\app\outputs\bundle\release\app-release.aab"
        if (![string]::IsNullOrWhiteSpace($Flavor)) {
            # Standard Gradle output for flavored appbundles is in outputs/bundle/<flavor>Release/
            $aabSource = "build\app\outputs\bundle\${Flavor}Release\app-$Flavor-release.aab"
        }

        $aabName    = "$projectName-v$appVersion+$buildNumber-$timestamp.aab"
        $aabArchive = Join-Path $aabFolder $aabName
        $aabLatest  = Join-Path $latestFolder "$projectName-release.aab"

        $ok1 = Copy-Artifact -Source $aabSource -Destination $aabArchive -Label "AAB_CREATED"
        $ok2 = Copy-Artifact -Source $aabSource -Destination $aabLatest  -Label "AAB_LATEST"
        if (!$ok1 -or !$ok2) { return }
        Write-Host "  AAB build completed." -ForegroundColor Green
        Write-Host "  Archived: $aabArchive" -ForegroundColor Cyan
    }

    # --- Optional Clean ---
    if ($Clean) {
        Write-Host "--- Running flutter clean ---" -ForegroundColor Yellow
        Write-Log "CLEAN" "STARTED"
        flutter clean
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  flutter clean failed." -ForegroundColor Red
            Write-Log "FAILED" "flutter clean exited with code $LASTEXITCODE"
            return
        }
        Write-Log "CLEAN" "COMPLETED"
        Write-Host "  Flutter clean completed." -ForegroundColor Green
    }

    # --- Final Summary ---
    $duration = [int](((Get-Date) - $startTime).TotalSeconds)
    Write-Log "END" "DURATION=$($duration)s"

    Write-Host "=====================================" -ForegroundColor Green
    Write-Host " Release Completed Successfully"      -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "  Release Path : $releaseRoot"
    Write-Host "  Log File     : $logFile"
    Write-Host "  Duration     : $($duration)s"

    # Open specific folder
    if (Test-Path $releaseRoot) { 
        Start-Process explorer.exe $releaseRoot 
    }
}
