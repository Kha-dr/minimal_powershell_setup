# Interactive console setup (skip for non-interactive hosts / redirected output)
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -HistorySearchCursorMovesToEnd -BellStyle None
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Related: https://github.com/PowerShell/PSReadLine/issues/1778
    Set-PSReadLineKeyHandler -Key Shift+Delete `
        -BriefDescription RemoveFromHistory `
        -LongDescription 'Removes the content of the current line from history' `
        -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        if ([string]::IsNullOrWhiteSpace($line)) { return }

        $historyPath = (Get-PSReadLineOption).HistorySavePath
        if (-not (Test-Path -LiteralPath $historyPath)) { return }

        $toRemove = [Regex]::Escape(($line -replace "`n", "```n"))
        $history = Get-Content -LiteralPath $historyPath -Raw
        if ($null -ne $history) {
            $updated = $history -replace "(?m)^$toRemove\r?\n?", ''
            Set-Content -LiteralPath $historyPath -Value $updated -NoNewline
        }
    }

    # Cache starship init script to avoid spawning starship.exe on every shell startup
    if ($starshipCmd = Get-Command starship -ErrorAction SilentlyContinue) {
        $starshipCache = Join-Path $env:TEMP 'starship-init.ps1'
        if (-not (Test-Path -LiteralPath $starshipCache) -or
            (Get-Item -LiteralPath $starshipCmd.Source).LastWriteTime -gt (Get-Item -LiteralPath $starshipCache).LastWriteTime) {
            & $starshipCmd.Source init powershell --print-full-init | Set-Content -LiteralPath $starshipCache -Encoding UTF8
        }
        . $starshipCache
    }

    # Lazy-load Terminal-Icons on idle so the prompt appears immediately
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        Import-Module -Name Terminal-Icons -Global -ErrorAction SilentlyContinue
    }
}

# Compute file or string hashes - useful for checking successful downloads
function Compute-Hash {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Value,
        [Parameter(Mandatory, Position = 1)]
        [string]$Algorithm
    )

    process {
        if (Test-Path -LiteralPath $Value -PathType Leaf) {
            Get-FileHash -LiteralPath $Value -Algorithm $Algorithm
        }
        else {
            $stream = [IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($Value))
            try {
                Get-FileHash -InputStream $stream -Algorithm $Algorithm
            }
            finally {
                $stream.Dispose()
            }
        }
    }
}
function md5 { param([Parameter(Mandatory, ValueFromPipeline)][string]$Value) process { Compute-Hash $Value MD5 } }
function sha1 { param([Parameter(Mandatory, ValueFromPipeline)][string]$Value) process { Compute-Hash $Value SHA1 } }
function sha256 { param([Parameter(Mandatory, ValueFromPipeline)][string]$Value) process { Compute-Hash $Value SHA256 } }

# Copy file(s)/folder(s) to the clipboard (pasteable in File Explorer / apps)
function Copy-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [string[]]$Path
    )

    begin {
        $resolved = [System.Collections.Generic.List[string]]::new()
    }
    process {
        foreach ($p in $Path) {
            foreach ($item in (Resolve-Path -Path $p -ErrorAction SilentlyContinue)) {
                $resolved.Add($item.ProviderPath)
            }
        }
    }
    end {
        if ($resolved.Count -gt 0) {
            Set-Clipboard -Path $resolved
        }
    }
}
Set-Alias -Name cf -Value Copy-File

# Copy resolved path (or current directory) as text to the clipboard
function Copy-Path {
    param([string]$Path = $PWD.ProviderPath)

    $resolved = (Resolve-Path -Path $Path -ErrorAction Stop).ProviderPath
    Set-Clipboard -Value $resolved
}
Set-Alias -Name cpwd -Value Copy-Path

if (-not (Get-Command sudo -CommandType Application -ErrorAction SilentlyContinue)) {
    function sudo {
        param(
            [Parameter(Mandatory, Position = 0)][string]$Command,
            [Parameter(ValueFromRemainingArguments)][string[]]$Arguments
        )

        $startArgs = @{ FilePath = $Command; Verb = 'RunAs' }
        if ($Arguments) { $startArgs.ArgumentList = $Arguments }
        Start-Process @startArgs
    }
}

function cdf {
    $selected = if (Get-Command fd -ErrorAction SilentlyContinue) {
        fd --type d | Invoke-Fzf
    }
    else {
        Get-ChildItem -Path . -Recurse -Directory -ErrorAction SilentlyContinue | Invoke-Fzf
    }
    if ($selected) { Set-Location -LiteralPath $selected }
}

function Open-File {
    $selected = if (Get-Command fd -ErrorAction SilentlyContinue) {
        fd --type f | Invoke-Fzf
    }
    else {
        Get-ChildItem -Path . -Recurse -File -ErrorAction SilentlyContinue | Invoke-Fzf
    }
    if ($selected) { Invoke-Item -LiteralPath $selected }
}

function Get-Hotkeys {
    Get-PSReadLineKeyHandler | Format-Table -AutoSize -Property Key, Function, Description
}

function Get-PubIP {
    (Invoke-RestMethod -Uri 'https://ifconfig.me/ip').Trim()
}

function Start-ElevatedPS {
    param([Parameter(Mandatory)][ScriptBlock]$Code)

    $exe = (Get-Process -Id $PID).Path
    Start-Process -FilePath $exe -Verb RunAs -ArgumentList '-NoExit', '-Command', $Code.ToString()
}

function find-file {
    param([Parameter(Mandatory)][string]$Name)

    Get-ChildItem -Recurse -Filter "*$Name*" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
}

function unzip {
    param(
        [Parameter(Mandatory)][string]$File,
        [string]$Destination = $PWD.ProviderPath
    )

    $resolved = (Resolve-Path -LiteralPath $File -ErrorAction Stop).ProviderPath
    Write-Host "Extracting '$resolved' to '$Destination'"
    Expand-Archive -LiteralPath $resolved -DestinationPath $Destination
}

# Reboot straight into UEFI/BIOS firmware settings
function ToTheBios {
    shutdown /r /fw /f /t 0
}

function Invoke-Starship-TransientFunction {
    & starship module shell
}

function lk {
    $target = walk @args
    if ($target) { Set-Location -LiteralPath $target }
}

function which {
    param([Parameter(Mandatory)][string]$Name)

    Get-Command -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty Source
}

function mkcd {
    param([Parameter(Mandatory)][string]$Path)

    New-Item -ItemType Directory -Path $Path -Force | Set-Location
}

function touch {
    param([Parameter(Mandatory)][string[]]$Path)

    foreach ($p in $Path) {
        if (Test-Path -LiteralPath $p) {
            (Get-Item -LiteralPath $p).LastWriteTime = Get-Date
        }
        else {
            $null = New-Item -ItemType File -Path $p
        }
    }
}

function reload {
    . $PROFILE
}

function Get-Port {
    param([Parameter(Mandatory)][int]$Port)

    Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
        Select-Object LocalAddress, LocalPort, State, OwningProcess, @{
            Name       = 'Process'
            Expression = { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName }
        }
}

function Get-ProfileHelp {
    param([string]$Filter)

    $commands = @(
        [pscustomobject]@{ Command = 'Copy-File (cf)';      Description = 'Copy file(s)/folder(s) to clipboard'; Example = 'cf report.pdf | ls *.png | cf' }
        [pscustomobject]@{ Command = 'Copy-Path (cpwd)';    Description = 'Copy resolved path (or cwd) as text'; Example = 'cpwd .\src' }
        [pscustomobject]@{ Command = 'Compute-Hash';        Description = 'Hash file or string (pipeline ok)';   Example = 'Compute-Hash file.zip MD5' }
        [pscustomobject]@{ Command = 'md5 / sha1 / sha256'; Description = 'Quick file or string hash';           Example = '"hello" | sha256' }
        [pscustomobject]@{ Command = 'sudo';                Description = 'Run command as admin (fallback)';     Example = 'sudo notepad hosts' }
        [pscustomobject]@{ Command = 'Start-ElevatedPS';    Description = 'Run script block in elevated shell';  Example = 'Start-ElevatedPS { rm file.pdf }' }
        [pscustomobject]@{ Command = 'cdf';                 Description = 'Fuzzy-find directory and cd into it'; Example = 'cdf' }
        [pscustomobject]@{ Command = 'Open-File';           Description = 'Fuzzy-find file and open it';         Example = 'Open-File' }
        [pscustomobject]@{ Command = 'lk';                  Description = 'Navigate directories with walk';      Example = 'lk' }
        [pscustomobject]@{ Command = 'find-file';           Description = 'Recursively find files/folders';      Example = 'find-file config' }
        [pscustomobject]@{ Command = 'unzip';               Description = 'Extract zip archive';                 Example = 'unzip file.zip .\out' }
        [pscustomobject]@{ Command = 'which';               Description = 'Show command/executable source path'; Example = 'which sudo' }
        [pscustomobject]@{ Command = 'mkcd';                Description = 'Create directory and cd into it';     Example = 'mkcd .\new-project' }
        [pscustomobject]@{ Command = 'touch';               Description = 'Create file or update timestamp';     Example = 'touch notes.md' }
        [pscustomobject]@{ Command = 'Get-Port';            Description = 'Show process using a local TCP port'; Example = 'Get-Port 3000' }
        [pscustomobject]@{ Command = 'Get-PubIP';           Description = 'Get public IP address';               Example = 'Get-PubIP' }
        [pscustomobject]@{ Command = 'Get-Hotkeys';         Description = 'List PSReadLine keybindings';         Example = 'Get-Hotkeys' }
        [pscustomobject]@{ Command = 'ToTheBios';           Description = 'Reboot into UEFI/BIOS settings';      Example = 'ToTheBios' }
        [pscustomobject]@{ Command = 'reload';              Description = 'Reload PowerShell profile';           Example = 'reload' }
        [pscustomobject]@{ Command = 'Get-ProfileHelp (myhelp)'; Description = 'Show this custom command help';  Example = 'myhelp hash' }
    )

    if ($Filter) {
        $commands = $commands | Where-Object {
            $_.Command -like "*$Filter*" -or $_.Description -like "*$Filter*"
        }
    }

    $commands | Format-Table -AutoSize
}
Set-Alias -Name myhelp -Value Get-ProfileHelp

# Optional machine-specific overrides (kept separate from the repo-managed profile)
$localProfile = Join-Path -Path (Split-Path -Path $PROFILE -Parent) -ChildPath 'profile.local.ps1'
if (Test-Path -LiteralPath $localProfile -PathType Leaf) {
    . $localProfile
}
