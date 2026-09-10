# PowerShell Profile Script
# This script is designed to enhance your PowerShell experience with custom functions and configurations.
# It includes robust error handling, performance optimizations, and detailed comments for maintainability.

# $script:ProfileLoadStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:ProfileVerbose = ($env:PROFILE_VERBOSE -eq '1')

function Write-ProfileInfo {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Color = 'DarkGray'
    )

    if ($script:ProfileVerbose) {
        Write-Host $Message -ForegroundColor $Color
    }
}

# Import the PowerToys CommandNotFound module for enhanced command discovery (Windows only)
if ($IsWindows) {
    try {
        Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction Stop
        Write-ProfileInfo -Message 'Imported Microsoft.WinGet.CommandNotFound.' -Color Green
    }
    catch {
        Write-Warning "Failed to import Microsoft.WinGet.CommandNotFound module. Ensure it is installed."
    }
}

# Add ~/bin to the PATH environment variable if not already present
$userBinPath = Join-Path $HOME 'bin'
if (Test-Path $userBinPath) {
    $paths = $env:Path -split [regex]::Escape([System.IO.Path]::PathSeparator)
    if ($paths -notcontains $userBinPath) {
        $env:Path = "$userBinPath$([System.IO.Path]::PathSeparator)$env:Path"
        Write-ProfileInfo -Message "Added $userBinPath to PATH." -Color Green
    }
}

# Admin elevation check — used for the banner and guards elsewhere in the profile
$isAdmin = if ($IsWindows) {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
else {
    (id -u) -eq 0
}

if ($isAdmin) {
    Write-Host "`n  !! Running as Administrator/Root !!`n" -ForegroundColor White -BackgroundColor DarkRed
}



# eza-backed directory listings.
$script:EzaBaseArgs = @(
    '--color=always',
    '--color-scale=all',
    '--color-scale-mode=gradient',
    '--icons=always',
    '--group-directories-first',
    '--header',
    '--time-style=long-iso'
)

function Invoke-DirectoryListing {
    param(
        [string]$Path = '.',
        [string[]]$Options = @()
    )

    if (Get-Command eza -ErrorAction SilentlyContinue) {
        & eza @script:EzaBaseArgs @Options $Path
        Write-Host "`n    Directory: " -NoNewline
        Write-Host "$(Get-Location)`n" -ForegroundColor Green
        return
    }

    Write-Warning 'eza is not installed. Install it with Homebrew on macOS/Linux or Scoop/WinGet on Windows.'
}


# Function: l
# Description: Enhanced directory listing including hidden and system files.
function l {
    param([string]$Path = '.')
    Invoke-DirectoryListing -Path $Path -Options @('--follow-symlinks', '-l', '-a')
}

# Function: ll
# Description: Long view; no hidden files
function ll {
    param([string]$Path = '.')
    Invoke-DirectoryListing -Path $Path -Options @('-l')
}

# Function: lg
# Description: Long view with Git status
function lg {
    param([string]$Path = '.')
    Invoke-DirectoryListing -Path $Path -Options @('-l', '--git')
}

# Function: ll
# Description: Long view; no hidden files
function la {
    param([string]$Path = '.')
    Invoke-DirectoryListing -Path $Path -Options @('-a')
}

function lt {
    param([string]$Path = '.')
    Invoke-DirectoryListing -Path $Path -Options @('-a', '-l', '--tree', '--level 2')
}

# Function: flf
# Description: Pipeline-aware Format-List with -Force enabled.
function flf {
    process {
        $_ | Format-List @args -Force
    }
}

# Git Shortcuts (Compact)
function gstat { git status -sb }
function glog { git log --oneline --graph --decorate -20 }
function gdiff { git diff }
function gco { git checkout @args }
function gpush { git add -A; git commit -m ($args -join ' ' -or "Sync update"); git push origin (git branch --show-current) }
function gpull {
  # TODO: run 'git remote -v' to list remtoes, then pull from $args (default:origin)
  git pull origin (git branch --show-current)
}

# Utilities
## Function: flf - Shorthand to format-list with a Force argument
function flf { process { $_ | Format-List @args -Force } }

## Function: cpwd - Copies the path of your current working directory to the clipboard
function cpwd { $PWD.Path | Set-Clipboard; Write-Host "Copied: $($PWD.Path)" -ForegroundColor Green }

## Function: Get-MyIP - Returns your current public IP address.
function Get-MyIP { try { (Invoke-RestMethod 'https://ifconfig.me/ip').Trim() } catch { Write-Warning "IP check failed" } }

## Function: o $Path - Opens an explorer window to the specified path, e.g. "o ." (Handy in terminal)
function o { param($Path = '.') if ($IsWindows) { explorer.exe $Path } elseif ($IsMacOS) { open $Path } else { xdg-open $Path } }

## Function: opens the current directory in VS Code
function c { param($Path = '.') if ($IsWindows) { code.cmd $Path } else { code $Path } }

## Function: opens the current directory in VS Code Insiders
function ci { param($Path = '.') if ($IsWindows) { code-insiders.cmd $Path } else { code-insiders $Path } }


# Function: pgrep
# Description: Find processes by name. Supports wildcards, -Exact, -Full, -Count, -Newest, -Oldest.
function pgrep {
    param([string]$Name, [switch]$Full, [switch]$Count)
    $procs = Get-Process "*$Name*" -ErrorAction SilentlyContinue
    if ($Count) { return $procs.Count }
    if ($Full) { $procs | Select-Object ProcessName, Id, CPU, WorkingSet, Path } else { $procs.Id }
}

# --- 4. Profile Management ---
function Reload-Profile { . $env:PS_ACTIVE_PROFILE; Write-Host "Profile reloaded." -ForegroundColor Green }

function Edit-Profile {
    $p = @{ '1' = $PROFILE.AllUsersAllHosts; '2' = $PROFILE.AllUsersCurrentHost; '3' = $PROFILE.CurrentUserAllHosts; '4' = $PROFILE.CurrentUserCurrentHost }
    Write-Host "`nEdit Profile:" -ForegroundColor Cyan
    $p.Keys | Sort-Object | ForEach-Object { Write-Host "  [$_] $($p[$_])" }
    $choice = Read-Host "`nPick (1-4)"
    if ($p.ContainsKey($choice)) { c $p[$choice] }
}

# --- 5. Module Initialization ---

# PSReadLine
if (Get-Module PSReadLine -ListAvailable) {
    try {
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
        Set-PSReadLineOption -BellStyle Visual

        # Copied straight out of the fzf handbook
        Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory
        Set-PSReadLineOption -AddToHistoryHandler { param($line) return $line -notlike ' *' }
    } catch {
        Write-Warning "PSReadLine initialization failed: $($_.Exception.Message)"
    }
}

function purge-badhistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Command
    )

    $historyPath = (Get-PSReadLineOption).HistorySavePath
    if (-not (Test-Path -LiteralPath $historyPath)) {
        Write-Warning "PSReadLine history file not found: $historyPath"
        return
    }

    $historyLines = Get-Content -LiteralPath $historyPath
    $matchCount = @($historyLines | Where-Object { $_ -ceq $Command }).Count
    $sessionMatches = @(Get-History | Where-Object { $_.CommandLine -ceq $Command })
    if ($matchCount -eq 0 -and $sessionMatches.Count -eq 0) {
        Write-Host 'No exact matching command found.' -ForegroundColor Yellow
        return
    }

    if ($matchCount -gt 0) {
        $backupPath = "$historyPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $historyPath -Destination $backupPath
        $historyLines |
            Where-Object { $_ -cne $Command } |
            Set-Content -LiteralPath $historyPath -Encoding utf8
    }

    $sessionMatches |
        ForEach-Object { Clear-History -Id $_.Id }

    $message = "Removed $matchCount saved and $($sessionMatches.Count) current-session exact history entr$(if (($matchCount + $sessionMatches.Count) -eq 1) { 'y' } else { 'ies' })."
    if ($backupPath) { $message += " Backup: $backupPath" }
    Write-Host $message -ForegroundColor Green
}

if (Get-Module PSReadLine -ListAvailable) {
    Set-PSReadLineKeyHandler -Key Alt+Delete `
        -BriefDescription PurgeHistoryEntry `
        -Description 'Purge the recalled command from saved and current-session history.' `
        -ScriptBlock {
            param($key, $arg)

            $line = $null
            $cursor = 0
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

            if ([string]::IsNullOrWhiteSpace($line)) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
                return
            }

            purge-badhistory -Command $line
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        }
}

# Function: pocket
# Description: Data-driven paginated quick-reference. To add a new function, add one
#              [pscustomobject] line to the appropriate section in $sections — alignment
#              is calculated automatically.
function pocket {
    # ── Add new entries here ─────────────────────────────────────────────────
    $sections = [ordered]@{
        'GIT'                      = @(
            [pscustomobject]@{ Name = 'gstat'; Desc = 'git status -sb' }
            [pscustomobject]@{ Name = 'glog'; Desc = 'git log --oneline --graph (last 20)' }
            [pscustomobject]@{ Name = 'gdiff'; Desc = 'git diff' }
            [pscustomobject]@{ Name = 'gco <branch>'; Desc = 'git checkout' }
            [pscustomobject]@{ Name = 'gpush [-Message]'; Desc = 'stage all, commit, push' }
            [pscustomobject]@{ Name = 'gpull [-Branch]'; Desc = 'pull origin <branch>' }
        )
        'FILESYSTEM'               = @(
            [pscustomobject]@{ Name = 'l [path]'; Desc = 'list all (hidden/system) via eza' }
            [pscustomobject]@{ Name = 'll [path]'; Desc = 'icon-rich long listing via eza' }
            [pscustomobject]@{ Name = 'lg [path]'; Desc = 'long listing with git status via eza' }
            [pscustomobject]@{ Name = 'lt [depth]'; Desc = 'tree view listing via eza' }
            [pscustomobject]@{ Name = 'cd <path>'; Desc = 'Smart jump (zoxide) + auto ll' }
            [pscustomobject]@{ Name = 'o <path>'; Desc = 'open in Explorer  (e.g. o .)' }
            [pscustomobject]@{ Name = 'cpwd'; Desc = 'copy current path to clipboard' }
        )
        'UTILITIES'                = @(
            [pscustomobject]@{ Name = 'flf'; Desc = 'pipeline-aware Format-List -Force' }
        )
        'PROCESS'                  = @(
            [pscustomobject]@{ Name = 'pgrep <name>'; Desc = 'find processes by name (PIDs)' }
            [pscustomobject]@{ Name = 'pgrep <name> -Full'; Desc = 'full process details' }
            [pscustomobject]@{ Name = 'pgrep <name> -Count'; Desc = 'count matching processes' }
            [pscustomobject]@{ Name = 'pgrep <name> -Newest'; Desc = 'PID of the newest match' }
            [pscustomobject]@{ Name = 'pgrep <name> -Exact'; Desc = 'exact name match only' }
        )
        'BOOKMARKS'                = @(
            [pscustomobject]@{ Name = 'mark <name>'; Desc = 'bookmark current dir' }
            [pscustomobject]@{ Name = 'jump <name>'; Desc = 'cd to a named bookmark' }
            [pscustomobject]@{ Name = 'marks'; Desc = 'list all bookmarks' }
            [pscustomobject]@{ Name = 'unmark <name>'; Desc = 'remove a bookmark' }
            [pscustomobject]@{ Name = 'marks-purge'; Desc = 'delete ALL bookmarks (confirms)' }
        )
        'PROFILE & SHELL'          = @(
            [pscustomobject]@{ Name = 'Edit-Profile'; Desc = 'pick and open a $PROFILE variant' }
            [pscustomobject]@{ Name = 'Install-ProfileSymlink'; Desc = 'link this profile to CurrentUser* target' }
            [pscustomobject]@{ Name = 'Reload-Profile'; Desc = 're-source $PROFILE in current shell' }
            [pscustomobject]@{ Name = 'purge-badhistory <command>'; Desc = 'remove exact command from saved history' }
            [pscustomobject]@{ Name = 'pocket'; Desc = 'show this reference (paginated)' }
            [pscustomobject]@{ Name = 'c'; Desc = 'launch Visual Studio Code' }
            [pscustomobject]@{ Name = 'ci'; Desc = 'launch Visual Studio Code Insiders' }
        )
        'NETWORK'                  = @(
            [pscustomobject]@{ Name = 'Get-MyIP'; Desc = 'display your public IP address' }
        )
        'KEYBINDINGS (PSReadLine)' = @(
            [pscustomobject]@{ Name = 'Ctrl+R'; Desc = 'reverse history search' }
            [pscustomobject]@{ Name = 'Arrow Down'; Desc = 'cycle ListView predictions' }
            [pscustomobject]@{ Name = 'Right Arrow'; Desc = 'accept current prediction' }
        )
    }
    # ── End of entries ───────────────────────────────────────────────────────

    $h = $PSStyle.Foreground.BrightCyan
    $l = $PSStyle.Foreground.BrightYellow
    $d = $PSStyle.Foreground.White
    $x = $PSStyle.Foreground.BrightBlack
    $r = $PSStyle.Reset

    $maxNameLen = (
        $sections.Values | ForEach-Object { $_ } |
        ForEach-Object { $_.Name.Length } |
        Measure-Object -Maximum
    ).Maximum

    $out = [System.Collections.Generic.List[string]]::new()
    $out.Add('')
    $out.Add("  ${h}PowerShell Profile  ·  Quick Reference${r}")

    foreach ($section in $sections.GetEnumerator()) {
        $out.Add('')
        $out.Add("  ${h}$($section.Key)${r}")
        foreach ($entry in $section.Value) {
            $pad = ' ' * ($maxNameLen - $entry.Name.Length)
            $out.Add("    ${l}$($entry.Name)${r}$pad  ${x}·${r}  ${d}$($entry.Desc)${r}")
        }
    }
    $out.Add('')
    ($out -join "`n") | Out-Host -Paging
}

try {
    $ompCommand = Get-Command oh-my-posh -ErrorAction Stop
    $customThemePath = Join-Path $HOME ".config/oh-my-posh/azure-jigs-omp.toml"

    # Never inherit a config path generated by an earlier shell session.
    Remove-Item Env:\POSH_CONFIG -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $customThemePath -PathType Leaf) {
        & $ompCommand.Path init pwsh --config $customThemePath | Invoke-Expression
    }
    else {
        & $ompCommand.Path init pwsh | Invoke-Expression
    }
}
catch {
    Write-Warning "Failed to initialize Oh-My-Posh prompt: $($_.Exception.Message)"
}


# *ZOXIDE* — Initialize zoxide for smart directory jumping (Must be at the EOF)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# Override cd function to include ll and zoxide integration (optimized)
if (Get-Alias cd -ErrorAction SilentlyContinue) { Remove-Item Alias:cd -Force }

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    function cd {
        param([Parameter(ValueFromRemainingArguments)]$Path)
        z @Path
        ll
    }
} else {
    function cd {
        param([Parameter(ValueFromRemainingArguments)]$Path)
        if (-not $Path) { Set-Location $HOME } else { Set-Location -Path $Path }
        ll
    }
}

# backlog.md shell completion
$completionScript = Join-Path (Split-Path -Parent $PROFILE.CurrentUserAllHosts) "Completions/backlog-completion.ps1"
if (Test-Path $completionScript) { . $completionScript }

if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch
}

Write-Host "Looking for more shell tricks? Check your pocket: pocket" -ForegroundColor DarkGray
