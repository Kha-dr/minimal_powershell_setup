<h1 align="center">
My Minimal Terminal Setup
</h1>

<h4 align="center">
<img src="https://img.shields.io/badge/PowerShell-7%2B-blue?style=for-the-badge&logo=powershell&color=8bd5ca&logoColor=D9E0EE&labelColor=302D41" />
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

## Install (PowerShell 7+ Run As Administrator)

> [!WARNING]  
> Requires **PowerShell 7+** (`winget install Microsoft.PowerShell`) and **Winget** [[See More..]](https://learn.microsoft.com/en-us/windows/package-manager/winget/).

Recommended to run in an elevated PowerShell 7 (`pwsh`) window:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm "https://raw.githubusercontent.com/khad1r/minimal_powershell_setup/main/setup.ps1" | iex
```

## Custom Commands

Type `My-<Tab>` to discover all custom commands, or run `myhelp` (`My-Help`).

| Command          | Alias(es)                        | Description                                                  | Example                              |
| ---------------- | -------------------------------- | ------------------------------------------------------------ | ------------------------------------ |
| `My-CopyFile`    | `cf`                             | Copy file(s)/folder(s) to clipboard (`fzf -m` if no args)    | `cf`, `cf report.pdf`, `ls *.png \| cf` |
| `My-CopyPath`    | `cpwd`                           | Copy resolved path (or current dir) as text                  | `cpwd`, `cpwd .\src`                 |
| `My-Hash`        | `Compute-Hash`, `md5`, `sha1`, `sha256` | Hash file or string (`<Tab>` completes algorithm)     | `My-Hash file.zip SHA256`            |
| `My-Sudo`        | `sudo` (fallback)                | Run as admin (uses built-in `sudo` on Win 11 24H2+)          | `sudo notepad example.txt`           |
| `My-ElevatedPS`  | `Start-ElevatedPS`               | Run PowerShell script block as admin                         | `My-ElevatedPS { rm file.pdf }`      |
| `My-CdFzf`       | `cdf`                            | Fuzzy-find a directory with `fd`/`fzf` and `cd` into it      | `cdf`                                |
| `My-OpenFile`    | `Open-File`                      | Fuzzy-find a file with `fd`/`fzf` and open it                | `My-OpenFile`                        |
| `My-Walk`        | `lk`                             | Navigate directories with `walk`                             | `lk`                                 |
| `My-FindFile`    | `find-file`                      | Find files/folders recursively                               | `find-file config`                   |
| `My-Tree`        | `Get-Tree`                       | Display directory tree (`-Depth`, `-Exclude`, `-All`, long-path safe) | `My-Tree -Depth 2`          |
| `My-Unzip`       | `unzip`                          | Extract a zip archive                                        | `unzip file.zip .\out`               |
| `My-Which`       | `which`                          | Show command/executable source (`<Tab>` completes commands)  | `which sudo`                         |
| `My-Mkcd`        | `mkcd`                           | Create a directory and `cd` into it                          | `mkcd .\new-project`                 |
| `My-Touch`       | `touch`                          | Create an empty file or update its timestamp                 | `touch notes.md`                     |
| `My-Port`        | `Get-Port`                       | Show process using a TCP port (`<Tab>` completes open ports) | `My-Port 3000`                       |
| `My-PublicIP`    | `Get-PubIP`                      | Get your public IP address                                   | `My-PublicIP`                        |
| `My-Hotkeys`     | `Get-Hotkeys`                    | List PSReadLine keybindings                                  | `My-Hotkeys`                         |
| `My-ToBios`      | `ToTheBios`                      | Reboot directly into UEFI/BIOS firmware settings             | `My-ToBios`                          |
| `My-Reload`      | `reload`                         | Reload the PowerShell profile                                | `reload`                             |
| `My-Help`        | `myhelp`                         | List custom commands (`<Tab>` completes command names)       | `myhelp`, `myhelp My-Hash`           |

> [!NOTE]
> **Windows 11 24H2+** includes native `sudo` (`Settings > System > For developers > Enable sudo`). When a native `sudo.exe` is available in `PATH`, the profile leaves it untouched; on older Windows versions it provides the `sudo` function fallback.

---

1. Try `sudo wt` or `sudo powershell` to start a terminal as admin.
2. To edit the Starship theme: `code $env:STARSHIP_CONFIG` (or `notepad $env:STARSHIP_CONFIG`).
3. To edit the profile: `code $PROFILE` or `notepad $PROFILE`.
4. For Windows Terminal settings, copy the content of [windows terminal.setting.json](<windows terminal.setting.json>) into your `settings.json`.
5. For native PowerShell appearance customization, [see this guide](https://www.isumsoft.com/windows-10/change-windows-powershell-font-layout.html).
