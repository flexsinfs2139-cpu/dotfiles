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

```powershell
# Oh My Posh
oh-my-posh init pwsh --config "$HOME\.dotfiles\oh-my-posh\theme.omp.json" | Invoke-Expression

# Zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# FZF
Invoke-Expression (& { (fzf --powershell) })

# Terminal Icons
Import-Module Terminal-Icons
```

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
├── powershell/
│   └── Microsoft.PowerShell_profile.ps1
├── oh-my-posh/
│   └── theme.omp.json
└── windows-terminal/
    └── settings.json
```

Clone and restore on a new machine:

```powershell
git clone <repo-url> $HOME\.dotfiles
```

Then copy:

```powershell
Copy-Item `
    "$HOME\.dotfiles\powershell\Microsoft.PowerShell_profile.ps1" `
    $PROFILE `
    -Force
```

Reload:

```powershell
. $PROFILE
```

Your terminal environment should now be fully restored.
