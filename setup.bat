@echo off
:: =========================================================
:: DOTFILES SETUP & SYMLINK ORCHESTRATOR
:: Platform: Windows (CMD)
:: Requirements: Run as Administrator (will auto-elevate)
:: =========================================================
setlocal enabledelayedexpansion

:: Check for Administrative Privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Requesting administrative privileges for symlink creation...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo =========================================================
echo  Dotfiles Setup & Symlink Orchestrator
echo =========================================================
echo.

:: Configuration Variables
set "DOTFILES_DIR=%USERPROFILE%\.dotfiles"
set "DEFAULT_REPO=https://github.com/yourusername/dotfiles.git"

:: Ask user for repo URL or use default
echo Enter your Dotfiles Git Repository URL:
echo (Press Enter to use current local directory if already cloned)
set /p "REPO_URL="

if "%REPO_URL%"=="" (
    :: If already cloned, verify if current directory is the dotfiles directory
    if exist "%~dp0powershell\profile.ps1" (
        echo [INFO] Using current folder as dotfiles source.
        set "DOTFILES_DIR=%~dp0"
        :: Remove trailing slash if any
        if "!DOTFILES_DIR:~-1!"=="\" set "DOTFILES_DIR=!DOTFILES_DIR:~0,-1!"
    ) else (
        echo [INFO] Defaulting to repository: %DEFAULT_REPO%
        set "REPO_URL=%DEFAULT_REPO%"
    )
)

:: Clone Repository if needed
if not "%REPO_URL%"=="" (
    if not exist "%DOTFILES_DIR%" (
        echo [INFO] Cloning repository to %DOTFILES_DIR%...
        git clone "%REPO_URL%" "%DOTFILES_DIR%"
        if %errorLevel% neq 0 (
            echo [ERROR] Git clone failed. Please verify the URL and your internet connection.
            pause
            exit /b
        )
    ) else (
        echo [INFO] Dotfiles folder already exists at %DOTFILES_DIR%.
    )
)

:: Dynamically query PowerShell Profile paths
echo [INFO] Querying PowerShell profile paths...
set "PWSH_PROFILE="
set "WIN_PS_PROFILE="

for /f "delims=" %%i in ('pwsh -NoProfile -Command "Write-Output $PROFILE" 2^>nul') do set "PWSH_PROFILE=%%i"
for /f "delims=" %%i in ('powershell -NoProfile -Command "Write-Output $PROFILE" 2^>nul') do set "WIN_PS_PROFILE=%%i"

:: ---------------------------------------------------------
:: 1. Setup PWSH (PowerShell 7) Symlink
:: ---------------------------------------------------------
if not "%PWSH_PROFILE%"=="" (
    echo [INFO] Setting up PowerShell 7 Profile...
    for %%f in ("%PWSH_PROFILE%") do set "PWSH_DIR=%%~dpf"
    if not exist "!PWSH_DIR!" mkdir "!PWSH_DIR!"
    
    if exist "%PWSH_PROFILE%" (
        echo [INFO] Backup existing profile to Microsoft.PowerShell_profile.ps1.bak
        move /y "%PWSH_PROFILE%" "%PWSH_PROFILE%.bak" >nul
    )
    
    echo [INFO] Linking %PWSH_PROFILE% to !DOTFILES_DIR!\powershell\profile.ps1
    mklink "%PWSH_PROFILE%" "!DOTFILES_DIR!\powershell\profile.ps1"
) else (
    echo [WARN] PowerShell 7 (pwsh) not detected on this system. Skipping.
)

:: ---------------------------------------------------------
:: 2. Setup Windows PowerShell Symlink
:: ---------------------------------------------------------
if not "%WIN_PS_PROFILE%"=="" (
    echo [INFO] Setting up Windows PowerShell Profile...
    for %%f in ("%WIN_PS_PROFILE%") do set "WIN_PS_DIR=%%~dpf"
    if not exist "!WIN_PS_DIR!" mkdir "!WIN_PS_DIR!"
    
    if exist "%WIN_PS_PROFILE%" (
        echo [INFO] Backup existing profile to Microsoft.PowerShell_profile.ps1.bak
        move /y "%WIN_PS_PROFILE%" "%WIN_PS_PROFILE%.bak" >nul
    )
    
    echo [INFO] Linking %WIN_PS_PROFILE% to !DOTFILES_DIR!\powershell\profile.ps1
    mklink "%WIN_PS_PROFILE%" "!DOTFILES_DIR!\powershell\profile.ps1"
)

:: ---------------------------------------------------------
:: 3. Setup Git Config Symlink
:: ---------------------------------------------------------
echo [INFO] Setting up Global Git Configuration...
set "GIT_CONFIG_DEST=%USERPROFILE%\.gitconfig"
if exist "%GIT_CONFIG_DEST%" (
    echo [INFO] Backup existing Git configuration to .gitconfig.bak
    move /y "%GIT_CONFIG_DEST%" "%GIT_CONFIG_DEST%.bak" >nul
)

echo [INFO] Linking %GIT_CONFIG_DEST% to !DOTFILES_DIR!\git\.gitconfig
mklink "%GIT_CONFIG_DEST%" "!DOTFILES_DIR!\git\.gitconfig"

:: Create empty platform specific configs if they do not exist (to prevent git errors)
if not exist "%USERPROFILE%\.gitconfig.windows" type nul > "%USERPROFILE%\.gitconfig.windows"
if not exist "%USERPROFILE%\.gitconfig.wsl" type nul > "%USERPROFILE%\.gitconfig.wsl"
if not exist "%USERPROFILE%\.gitconfig.macos" type nul > "%USERPROFILE%\.gitconfig.macos"

:: ---------------------------------------------------------
:: 4. Setup Daily Task Scheduler for Auto-Updates
:: ---------------------------------------------------------
echo [INFO] Registering daily update task in Windows Task Scheduler...
set "SCRIPT_PATH=!DOTFILES_DIR!\powershell\scripts\update-environment.ps1"
powershell -NoProfile -Command ^
    "$executable = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }; " ^
    "$Action = New-ScheduledTaskAction -Execute $executable -Argument '-NoProfile -WindowStyle Hidden -File ''!SCRIPT_PATH!'''; " ^
    "$Trigger = New-ScheduledTaskTrigger -Daily -At '10:00AM'; " ^
    "$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries; " ^
    "Register-ScheduledTask -TaskName 'UpdatePowerShellEnvironment' -Action $Action -Trigger $Trigger -Settings $Settings -Description 'Daily silent background updates for PowerShell modules, Winget CLI tools, and Git dotfiles.' -Force"

echo.
echo =========================================================
echo  Setup Completed Successfully!
echo  Open a new PowerShell terminal to verify.
echo =========================================================
echo.
pause
