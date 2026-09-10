# PowerShell Profile Script
# This script is designed to enhance your PowerShell experience with custom functions and configurations.
# It includes robust error handling, performance optimizations, and detailed comments for maintainability.

# To install module: Install-Module -Name Terminal-Icons -Repository PSGallery -Force
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    try {
        Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
    }
    catch {
        if ($debug) {
            Print-RBox "$($PSStyle.Foreground.Red)Failed to install Terminal-Icons module. Error: $_"
        }
    }
}
else {
    try {
        Import-Module -Name Terminal-Icons -Force

        # Define Catppuccin Mocha Palette (TrueColor)
        $mocha = [ordered]@{
            Sapphire = "$([char]27)[38;2;116;199;236m"
            Sky      = "$([char]27)[38;2;137;220;235m"
            Mauve    = "$([char]27)[38;2;203;166;247m"
            Yellow   = "$([char]27)[38;2;249;226;175m"
            Red      = "$([char]27)[38;2;243;139;168m"
            Pink     = "$([char]27)[38;2;245;194;231m"
            Teal     = "$([char]27)[38;2;148;226;213m"
            Overlay1 = "$([char]27)[38;2;127;132;156m"
            Reset    = "$([char]27)[0m"
            Bold     = "$([char]27)[1m"
        }

        # The "Power-User" Fix: Override the module's internal formatter.
        # Terminal-Icons builds its own strings, often ignoring external Bold settings.
        # We inject our own logic directly into the module scope.
        $tiModule = Get-Module Terminal-Icons
        if ($tiModule) {
            & $tiModule {
                function Format-TerminalIcons {
                    param(
                        [Parameter(Mandatory, ValueFromPipeline)]
                        [IO.FileSystemInfo]$FileInfo
                    )
                    process {
                        $display = Resolve-Icon $FileInfo
                        $bold    = if ($FileInfo.PSIsContainer) { "$([char]27)[1m" } else { "" }
                        $reset   = "$([char]27)[0m"

                        # Apply Catppuccin Colors for specific extensions
                        $color = $display.Color
                        switch ($FileInfo.Extension.ToLower()) {
                            ".ps1"  { $color = "$([char]27)[38;2;137;220;235m" } # Sky
                            ".json" { $color = "$([char]27)[38;2;203;166;247m" } # Mauve
                            ".exe"  { $color = "$([char]27)[38;2;249;226;175m" } # Yellow
                            ".cmd"  { $color = "$([char]27)[38;2;243;139;168m" } # Red
                            ".tf"   { $color = "$([char]27)[38;2;245;194;231m" } # Pink
                            ".md"   { $color = "$([char]27)[38;2;127;132;156m" } # Overlay1
                        }

                        if ($FileInfo.PSIsContainer -and ($color -eq $null -or $color -eq $script:colorReset)) {
                            $color = "$([char]27)[38;2;116;199;236m" # Sapphire for generic dirs
                        }

                        if ($display.Icon) {
                            return "$bold$color$($display.Icon)  $($FileInfo.Name)$($display.Target)$reset"
                        }
                        return "$bold$color$($FileInfo.Name)$($display.Target)$reset"
                    }
                }
            }
        }
    }
    catch {
        if ($debug) {
            Print-RBox "$($PSStyle.Foreground.Red)Failed to import Terminal-Icons module. Error: $_"
        }
    }
}

# Import the PowerToys CommandNotFound module for enhanced command discovery
try {
    Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction Stop
    Write-Host "Successfully imported Microsoft.WinGet.CommandNotFound module." -ForegroundColor Green
}
catch {
    Write-Warning "Failed to import Microsoft.WinGet.CommandNotFound module. Ensure it is installed."
}

# Add ~/bin to the PATH environment variable if not already present
$userBinPath = Join-Path $HOME 'bin'
$pathSeparator = [System.IO.Path]::PathSeparator
if (($env:Path -split [regex]::Escape($pathSeparator)) -notcontains $userBinPath) {
    $env:Path += "$pathSeparator$userBinPath"
    Write-Host "Added $userBinPath to PATH." -ForegroundColor Green
}
else {
    Write-Host "$userBinPath is already in PATH." -ForegroundColor Yellow
}

# Detect which $PROFILE slot loaded this script and record it for the session.
# Resolves symlinks so dot-source, copy, and symlink installs all work correctly.
# $env:PS_ACTIVE_PROFILE is process-scoped: it lives only while this host is running.
$_thisFile = try { (Resolve-Path -LiteralPath $PSCommandPath -ErrorAction Stop).Path } catch { $PSCommandPath }
$_cuah = try { (Resolve-Path -LiteralPath $PROFILE.CurrentUserAllHosts -ErrorAction Stop).Path } catch { $null }
$_cuch = try { (Resolve-Path -LiteralPath $PROFILE.CurrentUserCurrentHost -ErrorAction Stop).Path } catch { $null }
$env:PS_ACTIVE_PROFILE = if ($_cuah -and [string]::Equals($_thisFile, $_cuah, [System.StringComparison]::OrdinalIgnoreCase)) {
    $PROFILE.CurrentUserAllHosts
}
elseif ($_cuch -and [string]::Equals($_thisFile, $_cuch, [System.StringComparison]::OrdinalIgnoreCase)) {
    $PROFILE.CurrentUserCurrentHost
}
else {
    # Dot-sourced from a non-standard path; fall back to the default $PROFILE slot
    $PROFILE.CurrentUserCurrentHost
}
Remove-Variable _thisFile, _cuah, _cuch -ErrorAction SilentlyContinue

# Admin elevation check — used for the banner and guards elsewhere in the profile
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host ""
    Write-Host "  !! Running as Administrator !!" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host ""
}

# Function: gpush
# Description: Adds, commits, and pushes all changes to the current Git branch.
function gpush {
    param(
        [string]$Message = "Sync update",
        [string]$Branch
    )

    if (-not $Branch) {
        $Branch = git branch --show-current
    }

    if (-not $Branch) {
        throw "Could not determine the current Git branch."
    }

    try {
        git status --short
        git add -A
        git commit -m $Message
        git push origin $Branch
        Write-Host "Changes pushed to branch '$Branch'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to push changes: $_"
    }
}

# Function: gpull
# Description: Pulls the latest changes from the current Git branch.
function gpull {
    param(
        [string]$Branch
    )

    if (-not $Branch) {
        $Branch = git branch --show-current
    }

    if (-not $Branch) {
        throw "Could not determine the current Git branch."
    }
    try {
        git pull origin $Branch
        if ($LASTEXITCODE -ne 0) {
            throw "git pull failed with exit code $LASTEXITCODE."
        }
        Write-Host "Pulled latest changes for branch '$Branch'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to pull changes: $_"
    }
}

# Register argument completer for Azure CLI
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    $env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}

# Function: ll
# Description: Proxy function for Get-ChildItem that supports modern ANSI styling.
function ll {
    [CmdletBinding(DefaultParameterSetName = 'Items', HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=113308')]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Path,

        [Parameter(ParameterSetName = 'LiteralItems', ValueFromPipelineByPropertyName = $true)]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [Parameter(Position = 1)]
        [string]$Filter,

        [string[]]$Include,
        [string[]]$Exclude,
        [switch]$Recurse,
        [switch]$Force,
        [switch]$Name,
        [uint32]$Depth,
        $Attributes,
        [switch]$Directory,
        [switch]$File,
        [switch]$Hidden,
        [switch]$ReadOnly,
        [switch]$System
    )

    begin {
        try {
            $wrappedCmd = Get-Command -Name 'Get-ChildItem' -CommandType Cmdlet
            $scriptCmd = { & $wrappedCmd @PSBoundParameters @args }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        }
        catch {
            throw
        }
    }

    process {
        try {
            $steppablePipeline.Process($_)
        }
        catch {
            throw
        }
    }

    end {
        try {
            $steppablePipeline.End()
        }
        catch {
            throw
        }
    }
}

# Function: l
# Description: Enhanced directory listing including hidden and system files.
function l {
    ll -Force @args
}

# Override cd function to include ll and zoxide integration
# We remove the alias first because PowerShell's 'cd' alias takes precedence over functions.
if (Get-Alias cd -ErrorAction SilentlyContinue) { Remove-Item Alias:cd -Force }
function cd {
    param([Parameter(ValueFromRemainingArguments)]$Path)
    if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) {
        __zoxide_z @Path
    }
    else {
        if (-not $Path) { Set-Location $HOME }
        else { Set-Location -Path $Path }
    }
    ll
}

# Git shortcuts
function gstat { git status -sb }
function glog { git log --oneline --graph --decorate -20 }
function gdiff { git diff }
function gco { git checkout @args }

# Function: o
# Description: Opens a path in Windows Explorer.
function o {
    param([string]$Path = '.')
    explorer.exe $Path
}

# Function: cpwd
# Description: Copies the current working directory path to the clipboard.
function cpwd {
    $PWD.Path | Set-Clipboard
    Write-Host "Copied: $($PWD.Path)" -ForegroundColor Green
}

# Function: Get-MyIP
# Description: Returns your current public IP address.
function Get-MyIP {
    try {
        $result = Invoke-RestMethod -Uri 'https://ifconfig.me/ip' -TimeoutSec 5
        Write-Host $result.ip -ForegroundColor Cyan
        return $result.ip
    }
    catch {
        Write-Warning "Could not retrieve public IP: $_"
    }
}

# Function: c
# Description: Shortcut for Visual Studio Code (code.cmd)
function c {
    param([string]$ParamOrPath = '.')
    code.cmd $ParamOrPath
}

# Function: ci
# Description: Shortcut for Visual Studio Code (code.cmd)
function ci {
    param([string]$ParamOrPath = '.')
    code-insiders.cmd $ParamOrPath
}

# Function: Reload-Profile
# Description: Re-dot-sources whichever $PROFILE slot loaded this session.
#              The active slot is detected at startup and stored in $env:PS_ACTIVE_PROFILE.
function Reload-Profile {
    $target = if ($env:PS_ACTIVE_PROFILE) { $env:PS_ACTIVE_PROFILE } else { $PROFILE }
    . $target
    Write-Host "Profile reloaded ($target)." -ForegroundColor Green
}

# Function: Edit-Profile
# Description: Interactively pick and open one of the 4 $PROFILE variants in VS Code.
function Edit-Profile {
    $profiles = [ordered]@{
        '1' = @{ Label = 'AllUsersAllHosts'; Path = $PROFILE.AllUsersAllHosts }
        '2' = @{ Label = 'AllUsersCurrentHost'; Path = $PROFILE.AllUsersCurrentHost }
        '3' = @{ Label = 'CurrentUserAllHosts'; Path = $PROFILE.CurrentUserAllHosts }
        '4' = @{ Label = 'CurrentUserCurrentHost'; Path = $PROFILE.CurrentUserCurrentHost }
    }

    Write-Host "`nAvailable profiles:" -ForegroundColor Cyan
    foreach ($key in $profiles.Keys) {
        $entry = $profiles[$key]
        $accessible = Test-Path $entry.Path
        $statusLabel = if ($accessible) { 'exists' } else { 'not found' }
        $labelColor = if ($accessible) { 'Green' } else { 'DarkGray' }
        Write-Host "  [$key] $($entry.Label)" -ForegroundColor $labelColor -NoNewline
        Write-Host " ($statusLabel)" -ForegroundColor DarkGray
    }

    $choice = Read-Host "`nEnter number to edit (or Enter to cancel)"
    if (-not $profiles.ContainsKey($choice)) {
        Write-Host 'Cancelled.' -ForegroundColor Yellow
        return
    }

    $selected = $profiles[$choice]
    if (-not (Test-Path $selected.Path)) {
        Write-Warning "Profile file not accessible: $($selected.Path)"
        return
    }

    code $selected.Path
}

# Function: Install-ProfileSymlink
# Description: Creates/updates a symlink from this script to one of the current-user $PROFILE targets.
function Install-ProfileSymlink {
    [CmdletBinding()]
    param(
        [ValidateSet('CurrentUserAllHosts', 'CurrentUserCurrentHost')]
        [string]$TargetProfile,
        [switch]$Force
    )

    $sourcePath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    if (-not $sourcePath) {
        Write-Error 'Could not determine source profile path.'
        return
    }

    if (-not $TargetProfile) {
        Write-Host "`nChoose target profile to link:" -ForegroundColor Cyan
        Write-Host "  [1] CurrentUserAllHosts    -> $($PROFILE.CurrentUserAllHosts)"
        Write-Host "  [2] CurrentUserCurrentHost -> $($PROFILE.CurrentUserCurrentHost)"
        $choice = Read-Host 'Enter number (or Enter to cancel)'
        $TargetProfile = switch ($choice) {
            '1' { 'CurrentUserAllHosts' }
            '2' { 'CurrentUserCurrentHost' }
            default { '' }
        }

        if (-not $TargetProfile) {
            Write-Host 'Cancelled.' -ForegroundColor Yellow
            return
        }
    }

    $targetPath = switch ($TargetProfile) {
        'CurrentUserAllHosts' { $PROFILE.CurrentUserAllHosts }
        'CurrentUserCurrentHost' { $PROFILE.CurrentUserCurrentHost }
    }

    if (-not $targetPath) {
        Write-Error "Could not resolve target path for '$TargetProfile'."
        return
    }

    $resolvedSource = try { (Resolve-Path -LiteralPath $sourcePath -ErrorAction Stop).Path } catch { $sourcePath }
    $targetDir = Split-Path -Path $targetPath -Parent
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    if ([string]::Equals($resolvedSource, $targetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning 'Source and target are the same path; no symlink needed.'
        return
    }

    if (Test-Path -LiteralPath $targetPath) {
        $existingResolved = $null
        try { $existingResolved = (Resolve-Path -LiteralPath $targetPath -ErrorAction Stop).Path } catch {}

        if ($existingResolved -and [string]::Equals($existingResolved, $resolvedSource, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "Already linked: $targetPath -> $resolvedSource" -ForegroundColor Green
            return
        }

        if (-not $Force) {
            $confirm = Read-Host "Target exists ($targetPath). Replace it? [y/N]"
            if ($confirm -ne 'y') {
                Write-Host 'Cancelled.' -ForegroundColor Yellow
                return
            }
        }

        Remove-Item -LiteralPath $targetPath -Force
    }

    try {
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $resolvedSource -Force | Out-Null
        Write-Host "Created symlink: $targetPath -> $resolvedSource" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create symlink: $_"
    }
}

# PSMarks — persistent directory bookmarks stored in ~/.mello/.psmarks.json
$script:marksFile = Join-Path $HOME '.mello\.psmarks.json'
$script:marks = if (Test-Path $script:marksFile) {
    try { Get-Content $script:marksFile -Raw | ConvertFrom-Json -AsHashtable }
    catch { @{} }
}
else { @{} }

function _Save-Marks {
    $dir = Split-Path $script:marksFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $script:marks | ConvertTo-Json | Set-Content $script:marksFile
}

# Function: mark
# Description: Bookmark the current (or given) directory under a name.
function mark {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Path = $PWD.Path
    )
    $script:marks[$Name] = $Path
    _Save-Marks
    Write-Host "Marked '$Name' -> $Path" -ForegroundColor Green
}

# Function: jump
# Description: Navigate to a named bookmark.
function jump {
    param([Parameter(Mandatory)][string]$Name)
    if ($script:marks.ContainsKey($Name)) {
        Set-Location $script:marks[$Name]
    }
    else {
        Write-Warning "No mark named '$Name'. Use 'marks' to list all."
    }
}

# Function: marks
# Description: List all saved bookmarks.
function marks {
    if ($script:marks.Count -eq 0) {
        Write-Host "No marks saved." -ForegroundColor DarkGray
        return
    }
    $script:marks.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $exists = Test-Path $_.Value
        $color = if ($exists) { 'Cyan' } else { 'DarkGray' }
        $flag = if ($exists) { '' } else { ' (missing)' }
        Write-Host "  $($_.Name)" -ForegroundColor Yellow -NoNewline
        Write-Host " -> $($_.Value)$flag" -ForegroundColor $color
    }
}

# Function: unmark
# Description: Remove a named bookmark.
function unmark {
    param([Parameter(Mandatory)][string]$Name)
    if ($script:marks.ContainsKey($Name)) {
        $script:marks.Remove($Name)
        _Save-Marks
        Write-Host "Removed mark '$Name'." -ForegroundColor Yellow
    }
    else {
        Write-Warning "No mark named '$Name'."
    }
}

# Function: marks-purge
# Description: Delete ALL saved bookmarks after confirmation.
function marks-purge {
    if ($script:marks.Count -eq 0) {
        Write-Host "No marks to purge." -ForegroundColor DarkGray
        return
    }
    $confirm = Read-Host "Purge all $($script:marks.Count) mark(s)? [y/N]"
    if ($confirm -eq 'y') {
        $script:marks = @{}
        _Save-Marks
        Write-Host "All marks purged." -ForegroundColor Red
    }
    else {
        Write-Host "Cancelled." -ForegroundColor Yellow
    }
}

# Function: pgrep
# Description: Find processes by name. Supports wildcards, -Exact, -Full, -Count, -Newest, -Oldest.
function pgrep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [switch]$Exact,
        [switch]$Count,
        [switch]$Full,
        [switch]$Newest,
        [switch]$Oldest
    )

    try {
        $all = Get-Process -ErrorAction SilentlyContinue
        $results = if ($Exact) {
            $all | Where-Object { $_.ProcessName -eq $Name }
        }
        else {
            $all | Where-Object { $_.ProcessName -like "*$Name*" }
        }

        if ($Count) { return $results.Count }
        if (-not $results) { return }

        if ($Newest) {
            $results = $results |
            Where-Object { $_.StartTime } |
            Sort-Object StartTime -Descending |
            Select-Object -First 1
        }
        elseif ($Oldest) {
            $results = $results |
            Where-Object { $_.StartTime } |
            Sort-Object StartTime |
            Select-Object -First 1
        }

        if ($Full) {
            $results | Select-Object ProcessName, Id, StartTime, CPU, WorkingSet, Path
        }
        else {
            $results | Select-Object -ExpandProperty Id
        }
    }
    catch {
        Write-Error "pgrep: $_"
    }
}

# PSReadLine — history search and predictive IntelliSense
if (Get-Module -Name PSReadLine -ListAvailable) {
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -BellStyle Visual

    # Copied straight out of the fzf handbook
    Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory

    $psrlVersion = (Get-Module PSReadLine -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
    if ($psrlVersion -ge [version]'2.2.0') {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    else {
        Set-PSReadLineOption -PredictionSource History
    }

    # For commands that are prefixed with a space " " character, do not save it in history
    # Useful for commands in the terminal that could contain sensitive or secret information
    Set-PSReadLineOption -AddToHistoryHandler {
        param($command)
        # If the command starts with a space, don't save it to the history file
        if ($command -like ' *') { return $false }
        return $true
    }

    # History is saved in a file determined by (Get-PSReadLineOption).HistorySavePath
}

# Function: Write-RBox
# Description: Renders a string inside a Unicode box. ASCII-only for compatibility.
function Write-RBox {
    param(
        [Parameter(Mandatory)][string]$Text,
        [string]$BorderColor = $PSStyle.Foreground.Cyan
    )
    $rst = $PSStyle.Reset
    $lines = $Text -split "`r?`n|`r"
    $max = ($lines | ForEach-Object { ($_ -replace "`e\[[\d;]*m", '').Length } | Measure-Object -Maximum).Maximum
    $w = $max + 2

    Write-Host "$BorderColor+-$('-' * $w)-+$rst"
    foreach ($line in $lines) {
        if ($line -eq '#divider#') {
            Write-Host "$BorderColor+-$('-' * $w)-+$rst"
        }
        else {
            $plain = $line -replace "`e\[[\d;]*m", ''
            $pad = ' ' * ($max - $plain.Length)
            Write-Host "$BorderColor| $line$pad |$rst"
        }
    }
    Write-Host "$BorderColor+-$('-' * $w)-+$rst"
}

# Function: huh
# Description: Data-driven paginated quick-reference. To add a new function, add one
#              [pscustomobject] line to the appropriate section in $sections — alignment
#              is calculated automatically.
function huh {
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
            [pscustomobject]@{ Name = 'l [path]'; Desc = 'list all (hidden/system) with colors' }
            [pscustomobject]@{ Name = 'll [path]'; Desc = 'color-coded directory listing' }
            [pscustomobject]@{ Name = 'cd <path>'; Desc = 'Smart jump (zoxide) + auto ll' }
            [pscustomobject]@{ Name = 'o <path>'; Desc = 'open in Explorer  (e.g. o .)' }
            [pscustomobject]@{ Name = 'cpwd'; Desc = 'copy current path to clipboard' }
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
            [pscustomobject]@{ Name = 'huh'; Desc = 'show this reference (paginated)' }
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
    $ompThemePath = if ($env:POSH_THEMES_PATH) {
        Join-Path $env:POSH_THEMES_PATH 'jandedobbeleer.omp.json'
    }
    else {
        Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes\jandedobbeleer.omp.json'

    }

    # Resolve the physical path of the script to handle symlinks correctly
    $resolvedScriptPath = $PSCommandPath
    try {
        $item = Get-Item -LiteralPath $PSCommandPath -ErrorAction SilentlyContinue
        $linkTarget = if ($null -ne $item.LinkTarget) { $item.LinkTarget } elseif ($null -ne $item.Target) { $item.Target }
        if ($linkTarget -is [array]) { $linkTarget = $linkTarget[0] }

        if ($linkTarget) {
            # If the target is relative, make it absolute
            if (-not [System.IO.Path]::IsPathRooted($linkTarget)) {
                $linkTarget = Join-Path (Split-Path $PSCommandPath -Parent) $linkTarget
            }
            $resolvedScriptPath = $linkTarget
        }
    } catch {}

    $scriptDir = Split-Path -Path $resolvedScriptPath -Parent
    $customThemePath = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\oh-my-posh\azure-jigs-omp.toml"))

    if (Test-Path $customThemePath) {
        $ompThemePath = $customThemePath
    }

    $ompCacheDir = Join-Path $HOME '.mello'
    $ompCachePs1 = Join-Path $ompCacheDir 'omp-init-cache.ps1'
    $ompCacheVer = Join-Path $ompCacheDir 'omp-init-version.txt'
    $ompCurrentVer = oh-my-posh version 2>$null
    $ompCachedVer = if (Test-Path $ompCacheVer) { (Get-Content $ompCacheVer -Raw).Trim() } else { '' }

    if ($ompCurrentVer -ne $ompCachedVer -or -not (Test-Path $ompCachePs1)) {
        if (-not (Test-Path $ompCacheDir)) { New-Item -ItemType Directory -Path $ompCacheDir | Out-Null }
        oh-my-posh init pwsh --config $ompThemePath | Set-Content $ompCachePs1
        $ompCurrentVer | Set-Content $ompCacheVer
        Write-Host "Oh-My-Posh prompt cache refreshed ($ompCurrentVer)." -ForegroundColor Green
    }

    . $ompCachePs1
}
catch {
    Write-Warning "Failed to initialize Oh-My-Posh prompt. Ensure it is installed."
}

# *ZOXIDE* — Initialize zoxide for smart directory jumping (Must be at the EOF)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

Write-Host "PowerShell profile loaded." -ForegroundColor Green
