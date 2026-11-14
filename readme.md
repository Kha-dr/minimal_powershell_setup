<h1 align="center">
My Minimal Terminal Setup
</h1>

<h4 align="center">
<img src="https://img.shields.io/badge/Powershell-v5.1.22621.1778-blue?style=for-the-badge&logo=powershell&color=8bd5ca&logoColor=D9E0EE&labelColor=302D41" />
<img src="https://img.shields.io/badge/windows_terminal-v1.17.11461.0-blue?style=for-the-badge&logo=powershell&color=DDB6F2&logoColor=D9E0EE&labelColor=302D41" />
</h4>

## Introduction

A stylish and functional PowerShell profile that looks and feels almost as good as a Linux terminal, tuned for fast shell startup (cached Starship init and idle-loaded modules).

Advantages:

- Command suggestion dropdown and prefix history search (`ArrowUp` / `ArrowDown`)
- Command IntelliSense menu completion (`Tab` / `Ctrl + Space`)
- Terminal icons when listing files (`ls`, `ls | fw`, `ls | fl`)
- Delete a command from history with `Shift + Delete`
- Fast startup via cached `starship` init and idle-loaded `Terminal-Icons` (with `fd` support in `cdf` / `Open-File`)

## Install (PowerShell Run As Administrator)

> [!WARNING]  
> Make sure you have Winget installed. [[See More..]](https://learn.microsoft.com/en-us/windows/package-manager/winget/)

Recommended to run in an elevated PowerShell:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm "https://raw.githubusercontent.com/khad1r/minimal_powershell_setup/main/setup.ps1" | iex
```

## Custom Commands

| Command              | Description                                          | Arg                        | Example                                      |
| -------------------- | ---------------------------------------------------- | -------------------------- | -------------------------------------------- |
| `Copy-File` / `cf`   | Copy file(s)/folder(s) to clipboard (`Set-Clipboard -Path`) | path(s) / pipeline | `cf report.pdf`, `ls *.png \| cf`            |
| `Copy-Path` / `cpwd` | Copy resolved path (or current dir) as text          | path (optional)            | `cpwd`, `cpwd .\src`                         |
| `sudo`               | Run as admin (uses built-in `sudo` on Win 11 24H2+, fallback otherwise) | command, args | `sudo notepad example.txt`                   |
| `Start-ElevatedPS`   | Run PowerShell script block as admin                 | script block               | `Start-ElevatedPS { rm file.pdf }`           |
| `cdf`                | Fuzzy-find a directory with `fzf` and `cd` into it   | -                          | `cdf`                                        |
| `Open-File`          | Fuzzy-find a file with `fzf` and open it             | -                          | `Open-File`                                  |
| `lk`                 | Navigate directories with `walk`                     | optional args              | `lk`                                         |
| `Get-HotKeys`        | List PSReadLine keybindings                          | -                          | `Get-HotKeys`                                |
| `Get-PubIP`          | Get your public IP address                           | -                          | `Get-PubIP`                                  |
| `find-file`          | Find files/folders recursively                       | string                     | `find-file any`, `find-file "tes any"`       |
| `unzip`              | Extract a zip archive                                | zip path, destination      | `unzip file.zip`, `unzip file.zip .\out`     |
| `Compute-Hash`       | Calculate hash of a file or string (supports pipeline) | file/string, algorithm   | `Compute-Hash file.zip MD5`                  |
| `md5`                | Hash file or string with MD5                         | file/string / pipeline     | `md5 file.zip`, `"Hash this" \| md5`         |
| `sha1`               | Hash file or string with SHA1                        | file/string / pipeline     | `sha1 file.zip`, `"Hash this" \| sha1`       |
| `sha256`             | Hash file or string with SHA256                      | file/string / pipeline     | `sha256 file.zip`, `"Hash this" \| sha256`   |
| `ToTheBios`          | Reboot directly into UEFI/BIOS firmware settings     | -                          | `ToTheBios`                                  |
| `which`              | Show where a command/executable resolves from        | command name               | `which sudo`, `which git`                    |
| `mkcd`               | Create a directory and `cd` into it                  | path                       | `mkcd .\new-project`                         |
| `touch`              | Create an empty file or update its timestamp         | path(s)                    | `touch notes.md`                             |
| `reload`             | Reload the PowerShell profile                        | -                          | `reload`                                     |
| `Get-Port`           | Show which process is using a local TCP port         | port number                | `Get-Port 3000`                              |
| `Get-ProfileHelp` / `myhelp` | List all custom profile commands & examples  | filter (optional)          | `myhelp`, `myhelp hash`                      |

> [!NOTE]
> **Windows 11 24H2+** includes native `sudo` (`Settings > System > For developers > Enable sudo`). When a native `sudo.exe` is available in `PATH`, the profile leaves it untouched; on older Windows versions it provides the `sudo` function fallback.

---

1. Try `sudo wt` or `sudo powershell` to start a terminal as admin.
2. To edit the Starship theme: `code $env:STARSHIP_CONFIG` (or `notepad $env:STARSHIP_CONFIG`).
3. To edit the profile: `code $PROFILE` or `notepad $PROFILE`.
4. For Windows Terminal settings, copy the content of [windows terminal.setting.json](<windows terminal.setting.json>) into your `settings.json`.
5. For native PowerShell appearance customization, [see this guide](https://www.isumsoft.com/windows-10/change-windows-powershell-font-layout.html).
