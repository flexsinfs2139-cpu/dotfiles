Here's a clean `README.md` you can drop directly into your `.dotfiles` repository.

# Dotfiles

Personal Windows developer environment setup using PowerShell 7, Oh My Posh, Zoxide, FZF, Terminal Icons, and Windows Terminal.

---

# Prerequisites

## Install PowerShell 7

```powershell
winget install Microsoft.PowerShell
```

Verify:

```powershell
pwsh --version
```

---

# Windows Terminal

Install:

```powershell
winget install Microsoft.WindowsTerminal
```

Verify:

```powershell
wt
```

Windows Terminal settings file:

```powershell
$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

---

# Oh My Posh

Install:

```powershell
winget install JanDeDobbeleer.OhMyPosh
```

Verify:

```powershell
oh-my-posh version
```

View available themes:

```powershell
Get-ChildItem $env:POSH_THEMES_PATH
```

Initialize in PowerShell profile:

```powershell
oh-my-posh init pwsh --config "$HOME\.dotfiles\oh-my-posh\theme.omp.json" | Invoke-Expression
```

---

# Nerd Fonts

Required for Oh My Posh and Terminal Icons.

Install a Nerd Font:

```powershell
oh-my-posh font install
```

Recommended fonts:

* MesloLGM Nerd Font
* Cascadia Code Nerd Font
* JetBrainsMono Nerd Font

Configure Windows Terminal:

1. Open Windows Terminal
2. Settings
3. Select PowerShell Profile
4. Appearance
5. Font Face
6. Choose your installed Nerd Font

---

# Zoxide

Smart directory navigation.

Install:

```powershell
winget install ajeetdsouza.zoxide
```

Verify:

```powershell
zoxide --version
```

Initialize in PowerShell profile:

```powershell
Invoke-Expression (& { (zoxide init powershell | Out-String) })
```

## Common Commands

Jump to a directory:

```powershell
z Projects
```

```powershell
z Flutter
```

Interactive search:

```powershell
zi
```

View tracked directories:

```powershell
zoxide query -l
```

View tracked directories with scores:

```powershell
zoxide query -ls
```

Add directory manually:

```powershell
zoxide add D:\Projects\NewProject
```

Remove directory:

```powershell
zoxide remove D:\Projects\OldProject
```

Database location:

```text
%LOCALAPPDATA%\zoxide\db.zo
```

---

# FZF

Fuzzy finder used by Zoxide and PowerShell.

Install:

```powershell
winget install junegunn.fzf
```

Verify:

```powershell
fzf --version
```

Initialize in PowerShell profile:

```powershell
Invoke-Expression (& { (fzf --powershell) })
```

Useful shortcuts:

## Reverse Search

```text
Ctrl + R
```

## Interactive Zoxide

```powershell
zi
```

---

# Terminal Icons

Adds file and folder icons to PowerShell.

Install:

```powershell
Install-Module Terminal-Icons -Repository PSGallery -Scope CurrentUser
```

Import in PowerShell profile:

```powershell
Import-Module Terminal-Icons
```

Test:

```powershell
Get-ChildItem
```

---

# PowerShell Profile

Profile location:

```powershell
$PROFILE
```

Open profile:

```powershell
notepad $PROFILE
```

Reload profile:

```powershell
. $PROFILE
```

---

# Recommended Profile Setup

To keep your profile clean and leverage the modular configuration, add the following single line to your PowerShell profile (`$PROFILE`) to dot-source the main config loader:

```powershell
. "$HOME\.dotfiles\powershell\profile.ps1"
```

This loader will dynamically resolve your workspaces, import the required plugins (Oh My Posh, Zoxide, FZF, and Terminal Icons) with safety checks, and load your custom aliases and utilities.

---

# Verification

Run the following commands:

```powershell
oh-my-posh version
zoxide --version
fzf --version
Get-Module Terminal-Icons -ListAvailable
```

Verify:

* PowerShell prompt is styled by Oh My Posh
* Nerd Font icons render correctly
* `z` command works
* `zi` launches interactive search
* Folder icons appear in directory listings

---

# Useful Commands

## Reload Profile

```powershell
. $PROFILE
```

## Open Current Directory in VS Code

```powershell
code .
```

## Show Hidden Files

```powershell
Get-ChildItem -Force
```

## Locate Executable

```powershell
Get-Command <command>
```

Example:

```powershell
Get-Command git
```

---

# Backup Strategy

Store the following in Git:

```text
.dotfiles/
├── README.md
├── git/
│   └── .gitconfig
├── oh-my-posh/
│   └── theme.omp.json
└── powershell/
    ├── profile.ps1
    └── modules/
        ├── completions.ps1
        ├── aliases.ps1
        ├── utilities.ps1
        └── flutter-builder.ps1
```

Clone and restore on a new machine:

### Option 1: Automated Setup Script (Recommended)
This method automatically backs up existing settings, queries the profile locations for both PowerShell 7 (pwsh) and Windows PowerShell, and sets up symbolic links automatically.

1. Clone the repository:
   ```powershell
   git clone <repo-url> $HOME\.dotfiles
   ```
2. Navigate into the folder and run `setup.bat`:
   ```powershell
   cd $HOME\.dotfiles
   .\setup.bat
   ```
   *(The script will automatically request Administrator elevation to allow creation of symbolic links).*

### Option 2: Manual Profile Sourcing
If you prefer not to use symbolic links, you can manually append the dot-sourcing line to your profile:

```powershell
# Create profile if it doesn't exist
if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }

# Append dot-sourcing command to your profile
Add-Content -Path $PROFILE -Value '. "$HOME\.dotfiles\powershell\profile.ps1"'
```

Reload:

```powershell
. $PROFILE
```

Your terminal environment should now be fully restored.
