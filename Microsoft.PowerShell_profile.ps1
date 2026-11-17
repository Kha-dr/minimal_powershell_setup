#Requires -Version 7.0

# Interactive console setup (skip for non-interactive hosts / redirected output)
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -HistorySearchCursorMovesToEnd -BellStyle None
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Cache starship init script to avoid PATH lookup and spawning starship.exe on startup
    $starshipCache = Join-Path -Path $env:TEMP -ChildPath 'starship-init.ps1'
    if (Test-Path -LiteralPath $starshipCache -PathType Leaf) {
        . $starshipCache
    }
    elseif ($starshipCmd = Get-Command starship -ErrorAction SilentlyContinue) {
        & $starshipCmd.Source init powershell --print-full-init | Set-Content -LiteralPath $starshipCache -Encoding UTF8
        . $starshipCache
    }

    Write-Host 'myhelp • My-<Tab> • Shift+Del: remove history • F2: toggle view' -ForegroundColor DarkGray

    # Lazy-load Terminal-Icons, Shift+Delete handler, and argument completers on idle so the prompt appears immediately
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        Import-Module -Name Terminal-Icons -Global -ErrorAction SilentlyContinue

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
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        }

        Register-ArgumentCompleter -CommandName @('My-Help', 'myhelp') -ParameterName Filter -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $global:MyProfileCommands.Command |
                Where-Object { $_ -like "$wordToComplete*" } |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }

        Register-ArgumentCompleter -CommandName @('My-Which', 'which') -ParameterName Name -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            Get-Command -Name "$wordToComplete*" -ErrorAction SilentlyContinue |
                Select-Object -First 30 -ExpandProperty Name |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }

        Register-ArgumentCompleter -CommandName @('My-Port', 'Get-Port') -ParameterName Port -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty LocalPort -Unique |
                Sort-Object |
                Where-Object { "$_".StartsWith($wordToComplete) } |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new("$_", "$_", 'ParameterValue', "Listening port $_") }
        }
    }
}

# Starship transient prompt hook (name required by Starship)
function Invoke-Starship-TransientFunction {
    & starship module shell
}

# Compute file or string hashes
function My-Hash {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Value,
        [Parameter(Mandatory, Position = 1)]
        [ValidateSet('SHA256', 'SHA1', 'MD5', 'SHA384', 'SHA512')]
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
Set-Alias -Name Compute-Hash -Value My-Hash
function md5 { param([Parameter(Mandatory, ValueFromPipeline)][string]$Value) process { My-Hash $Value MD5 } }
function sha1 { param([Parameter(Mandatory, ValueFromPipeline)][string]$Value) process { My-Hash $Value SHA1 } }
function sha256 { param([Parameter(Mandatory, ValueFromPipeline)][string]$Value) process { My-Hash $Value SHA256 } }

# Shared fd/Get-ChildItem + fzf picker (includes hidden dotfiles, excludes .git internals)
function Invoke-MyFzf {
    param(
        [ValidateSet('All', 'File', 'Directory')][string]$Type = 'All',
        [switch]$Multi,
        [string]$Query
    )

    $fzfArgs = @()
    if ($Multi) { $fzfArgs += '-m' }
    if ($Query) { $fzfArgs += @('--query', $Query) }

    if (Get-Command fd -ErrorAction SilentlyContinue) {
        $fdArgs = @('--hidden', '--exclude', '.git')
        if ($Type -eq 'File') { $fdArgs += @('--type', 'f') }
        elseif ($Type -eq 'Directory') { $fdArgs += @('--type', 'd') }
        fd @fdArgs | fzf @fzfArgs
    }
    else {
        $gciArgs = @{ Path = '.'; Recurse = $true; Force = $true; ErrorAction = 'SilentlyContinue' }
        if ($Type -eq 'File') { $gciArgs.File = $true }
        elseif ($Type -eq 'Directory') { $gciArgs.Directory = $true }
        (Get-ChildItem @gciArgs).FullName | fzf @fzfArgs
    }
}

# Copy file(s)/folder(s) to the clipboard (pasteable in File Explorer / apps); run with no args to pick via fzf
function My-CopyFile {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [string[]]$Path
    )

    begin {
        $resolved = [System.Collections.Generic.List[string]]::new()
        $hasInput = $false
    }
    process {
        if ($null -eq $Path -or $Path.Count -eq 0) { return }
        $hasInput = $true
        foreach ($p in $Path) {
            foreach ($item in (Resolve-Path -Path $p -ErrorAction SilentlyContinue)) {
                $resolved.Add($item.ProviderPath)
            }
        }
    }
    end {
        if (-not $hasInput) {
            foreach ($s in (Invoke-MyFzf -Multi)) {
                foreach ($item in (Resolve-Path -LiteralPath $s -ErrorAction SilentlyContinue)) {
                    $resolved.Add($item.ProviderPath)
                }
            }
        }

        if ($resolved.Count -eq 0) { return }

        Add-Type -AssemblyName System.Windows.Forms
        $fileList = [System.Collections.Specialized.StringCollection]::new()
        $fileList.AddRange($resolved.ToArray())
        [System.Windows.Forms.Clipboard]::SetFileDropList($fileList)
    }
}
Set-Alias -Name cf -Value My-CopyFile

# Copy resolved path (or current directory) as text to the clipboard
function My-CopyPath {
    param([string]$Path = $PWD.ProviderPath)

    $resolved = (Resolve-Path -Path $Path -ErrorAction Stop).ProviderPath
    Set-Clipboard -Value $resolved
}
Set-Alias -Name cpwd -Value My-CopyPath

if (-not (Test-Path -LiteralPath "$env:SystemRoot\System32\sudo.exe" -PathType Leaf)) {
    function My-Sudo {
        param(
            [Parameter(Mandatory, Position = 0)][string]$Command,
            [Parameter(ValueFromRemainingArguments)][string[]]$Arguments
        )

        $startArgs = @{ FilePath = $Command; Verb = 'RunAs' }
        if ($Arguments) { $startArgs.ArgumentList = $Arguments }
        Start-Process @startArgs
    }
    Set-Alias -Name sudo -Value My-Sudo
}

function My-CdFzf {
    $selected = Invoke-MyFzf -Type Directory
    if ($selected) { Set-Location -LiteralPath $selected }
}
Set-Alias -Name cdf -Value My-CdFzf

function My-OpenFile {
    $selected = Invoke-MyFzf -Type File
    if ($selected) { Invoke-Item -LiteralPath $selected }
}
Set-Alias -Name Open-File -Value My-OpenFile

function My-Code {
    param([string]$Query)

    $selected = Invoke-MyFzf -Multi -Query $Query
    if ($selected) { code @selected }
}
Set-Alias -Name codef -Value My-Code

function My-Hotkeys {
    Get-PSReadLineKeyHandler | Format-Table -AutoSize -Property Key, Function, Description
}
Set-Alias -Name Get-Hotkeys -Value My-Hotkeys

function My-PublicIP {
    (Invoke-RestMethod -Uri 'https://ifconfig.me/ip').Trim()
}
Set-Alias -Name Get-PubIP -Value My-PublicIP

function My-ElevatedPS {
    param([Parameter(Mandatory)][ScriptBlock]$Code)

    $exe = (Get-Process -Id $PID).Path
    Start-Process -FilePath $exe -Verb RunAs -ArgumentList '-NoExit', '-Command', $Code.ToString()
}
Set-Alias -Name Start-ElevatedPS -Value My-ElevatedPS

function My-FindFile {
    param([Parameter(Mandatory)][string]$Name)

    Get-ChildItem -Recurse -Filter "*$Name*" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
}
Set-Alias -Name find-file -Value My-FindFile

function My-Unzip {
    param(
        [Parameter(Mandatory)][string]$File,
        [string]$Destination = $PWD.ProviderPath
    )

    $resolved = (Resolve-Path -LiteralPath $File -ErrorAction Stop).ProviderPath
    Write-Host "Extracting '$resolved' to '$Destination'"
    Expand-Archive -LiteralPath $resolved -DestinationPath $Destination
}
Set-Alias -Name unzip -Value My-Unzip

# Reboot straight into UEFI/BIOS firmware settings
function My-ToBios {
    shutdown /r /fw /f /t 0
}
Set-Alias -Name ToTheBios -Value My-ToBios

function My-Walk {
    $target = walk @args
    if ($target) { Set-Location -LiteralPath $target }
}
Set-Alias -Name lk -Value My-Walk

function My-Which {
    param([Parameter(Mandatory)][string]$Name)

    $cmd = Get-Command -Name $Name -ErrorAction Stop
    if ($cmd.Source) {
        $cmd.Source
    }
    elseif ($cmd.CommandType -eq 'Alias') {
        "$($cmd.Name) -> $($cmd.Definition)"
    }
    else {
        "$($cmd.CommandType): $($cmd.Name)"
    }
}
Set-Alias -Name which -Value My-Which

function My-Mkcd {
    param([Parameter(Mandatory)][string]$Path)

    New-Item -ItemType Directory -Path $Path -Force | Set-Location
}
Set-Alias -Name mkcd -Value My-Mkcd

function My-Touch {
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
Set-Alias -Name touch -Value My-Touch

function My-Reload {
    . $PROFILE
}
Set-Alias -Name reload -Value My-Reload

function My-Port {
    param([Parameter(Mandatory)][int]$Port)

    Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
        Select-Object LocalAddress, LocalPort, State, OwningProcess, @{
            Name       = 'Process'
            Expression = { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName }
        }
}
Set-Alias -Name Get-Port -Value My-Port

function My-Tree {
    param(
        [Parameter(Position = 0)][string]$Path = '.',
        [int]$Depth = [int]::MaxValue,
        [string[]]$Exclude = @('.git', 'node_modules'),
        [switch]$All
    )

    $rootPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    Write-Host $rootPath -ForegroundColor Cyan

    function Show-TreeNode {
        param([string]$CurrentPath, [string]$Prefix, [int]$Level)

        if ($Level -ge $Depth) { return }

        $safePath = if ($CurrentPath -match '^[A-Za-z]:\\' -and -not $CurrentPath.StartsWith('\\?\')) {
            "\\?\$CurrentPath"
        }
        else {
            $CurrentPath
        }

        $items = Get-ChildItem -LiteralPath $safePath -Force:$All -ErrorAction SilentlyContinue |
            Where-Object { $All -or ($Exclude -notcontains $_.Name) } |
            Sort-Object @{ Expression = 'PSIsContainer'; Descending = $true }, Name

        $count = @($items).Count
        for ($i = 0; $i -lt $count; $i++) {
            $item = $items[$i]
            $isLast = ($i -eq ($count - 1))
            $connector = if ($isLast) { '└── ' } else { '├── ' }

            Write-Host "$Prefix$connector" -NoNewline
            if ($item.PSIsContainer) {
                Write-Host $item.Name -ForegroundColor Cyan
                # Skip symlinks/junctions to prevent infinite recursion loops
                if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                    $childPrefix = $Prefix + $(if ($isLast) { '    ' } else { '│   ' })
                    Show-TreeNode -CurrentPath $item.FullName -Prefix $childPrefix -Level ($Level + 1)
                }
            }
            else {
                Write-Host $item.Name
            }
        }
    }

    Show-TreeNode -CurrentPath $rootPath -Prefix '' -Level 0
}
Set-Alias -Name Get-Tree -Value My-Tree

$global:MyProfileCommands = @(
    [pscustomobject]@{ Command = 'My-CopyFile';   Alias = 'cf';               Description = 'Copy file(s)/folder(s) to clipboard (fzf if no args)'; Example = 'cf | cf report.pdf | ls *.png | cf' }
    [pscustomobject]@{ Command = 'My-CopyPath';   Alias = 'cpwd';             Description = 'Copy resolved path (or cwd) as text'; Example = 'cpwd .\src' }
    [pscustomobject]@{ Command = 'My-Hash';       Alias = 'Compute-Hash, md5, sha1, sha256'; Description = 'Hash file or string'; Example = 'My-Hash file.zip SHA256' }
    [pscustomobject]@{ Command = 'My-Sudo';       Alias = 'sudo (fallback)';  Description = 'Run command as admin';                Example = 'sudo notepad hosts' }
    [pscustomobject]@{ Command = 'My-ElevatedPS'; Alias = 'Start-ElevatedPS'; Description = 'Run script block in elevated shell';  Example = 'My-ElevatedPS { rm file.pdf }' }
    [pscustomobject]@{ Command = 'My-CdFzf';      Alias = 'cdf';              Description = 'Fuzzy-find directory and cd into it'; Example = 'cdf' }
    [pscustomobject]@{ Command = 'My-OpenFile';   Alias = 'Open-File';        Description = 'Fuzzy-find file and open it';         Example = 'My-OpenFile' }
    [pscustomobject]@{ Command = 'My-Code';       Alias = 'codef';            Description = 'Fuzzy-find file/folder and open in VS Code'; Example = 'codef | codef profile' }
    [pscustomobject]@{ Command = 'My-Walk';       Alias = 'lk';               Description = 'Navigate directories with walk';      Example = 'lk' }
    [pscustomobject]@{ Command = 'My-FindFile';   Alias = 'find-file';        Description = 'Recursively find files/folders';      Example = 'find-file config' }
    [pscustomobject]@{ Command = 'My-Tree';       Alias = 'Get-Tree';         Description = 'Display directory tree (long-path safe)'; Example = 'My-Tree -Depth 2' }
    [pscustomobject]@{ Command = 'My-Unzip';      Alias = 'unzip';            Description = 'Extract zip archive';                 Example = 'unzip file.zip .\out' }
    [pscustomobject]@{ Command = 'My-Which';      Alias = 'which';            Description = 'Show command/executable source path'; Example = 'which sudo' }
    [pscustomobject]@{ Command = 'My-Mkcd';       Alias = 'mkcd';             Description = 'Create directory and cd into it';     Example = 'mkcd .\new-project' }
    [pscustomobject]@{ Command = 'My-Touch';      Alias = 'touch';            Description = 'Create file or update timestamp';     Example = 'touch notes.md' }
    [pscustomobject]@{ Command = 'My-Port';       Alias = 'Get-Port';         Description = 'Show process using a local TCP port'; Example = 'My-Port 3000' }
    [pscustomobject]@{ Command = 'My-PublicIP';   Alias = 'Get-PubIP';        Description = 'Get public IP address';               Example = 'My-PublicIP' }
    [pscustomobject]@{ Command = 'My-Hotkeys';    Alias = 'Get-Hotkeys';      Description = 'List PSReadLine keybindings';         Example = 'My-Hotkeys' }
    [pscustomobject]@{ Command = 'My-ToBios';     Alias = 'ToTheBios';        Description = 'Reboot into UEFI/BIOS settings';      Example = 'My-ToBios' }
    [pscustomobject]@{ Command = 'My-Reload';     Alias = 'reload';           Description = 'Reload PowerShell profile';           Example = 'reload' }
    [pscustomobject]@{ Command = 'My-Help';       Alias = 'myhelp';           Description = 'Show this custom command help';       Example = 'myhelp My-Hash' }
)

function My-Help {
    param([string]$Filter)

    $list = $global:MyProfileCommands
    if ($Filter) {
        $list = $list | Where-Object {
            $_.Command -like "*$Filter*" -or $_.Alias -like "*$Filter*" -or $_.Description -like "*$Filter*"
        }
    }

    $list | Format-Table -AutoSize
}
Set-Alias -Name myhelp -Value My-Help

# Optional machine-specific overrides (kept separate from the repo-managed profile)
if ($PROFILE) {
    $localProfile = Join-Path -Path (Split-Path -Path $PROFILE -Parent) -ChildPath 'profile.local.ps1'
    if (Test-Path -LiteralPath $localProfile -PathType Leaf) {
        . $localProfile
    }
}
