# Stripped old profile — pending functions for review/integration
# Only the 11 recommended functions remain. Everything else has been removed.
# Do NOT dot-source this file into the active profile until reviewed.

# ── Terraform shortcuts ───────────────────────────────────────────────────────

function tf  { terraform $args }
function tfi { terraform init -upgrade $args }
function tfp { terraform plan $args }
function tfa { terraform apply -auto-approve $args }
function tfd { terraform destroy -auto-approve $args }

# ── File utilities ────────────────────────────────────────────────────────────

# touch: create an empty file (or update its timestamp if it exists)
function touch {
    param([Parameter(Mandatory)][string]$File)
    if (Test-Path $File) {
        (Get-Item $File).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $File | Out-Null
    }
}

# mkcd: create a directory and cd into it
function mkcd {
    param([Parameter(Mandatory)][string]$Dir)
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    Set-Location $Dir
}

# ── Text processing ───────────────────────────────────────────────────────────

# grep: search for a regex pattern in files or pipeline input
function grep {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Regex,
        [Parameter(Position = 1)][string]$Dir
    )
    if ($Dir) {
        Get-ChildItem $Dir | Select-String $Regex
    } else {
        $input | Select-String $Regex
    }
}

# sed: replace all occurrences of a string in a file (in-place)
# Note: uses regex escape so literal strings are matched safely
function sed {
    param(
        [Parameter(Mandatory, Position = 0)][string]$File,
        [Parameter(Mandatory, Position = 1)][string]$Find,
        [Parameter(Mandatory, Position = 2)][string]$Replace
    )
    (Get-Content $File) -replace [regex]::Escape($Find), $Replace | Set-Content $File
}

# head: display the first N lines of a file
function head {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Path,
        [int]$n = 10
    )
    Get-Content $Path -Head $n
}

# tail: display the last N lines of a file; -f follows new output (like tail -f)
function tail {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Path,
        [int]$n = 10,
        [switch]$f
    )
    Get-Content $Path -Tail $n -Wait:$f
}

# ── Command discovery ─────────────────────────────────────────────────────────

# which: show the resolved path or definition of any command
function which {
    param([Parameter(Mandatory)][string]$Name)
    Get-Command $Name -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Definition
}

# ── Environment ───────────────────────────────────────────────────────────────

# export: set a session-scoped environment variable (UNIX-style syntax)
function export {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter(Mandatory, Position = 1)][string]$Value
    )
    Set-Item -Force -Path "env:$Name" -Value $Value
}

# ── System info ───────────────────────────────────────────────────────────────

# uptime: display time since last boot in *NIX style
function uptime {
    try {
        $bootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $up = (Get-Date) - $bootTime
        Write-Host ("System started: {0}" -f $bootTime.ToString("dddd, MMMM dd, yyyy HH:mm:ss")) -ForegroundColor DarkGray
        Write-Host ("Uptime:         {0}d {1}h {2}m {3}s" -f $up.Days, $up.Hours, $up.Minutes, $up.Seconds) -ForegroundColor Cyan
    } catch {
        Write-Error "Could not retrieve uptime: $_"
    }
}

# ── Networking ────────────────────────────────────────────────────────────────

# flushdns: clear the DNS client resolver cache
function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS cache flushed." -ForegroundColor Green
}

# ── Argument completers ───────────────────────────────────────────────────────

# Winget tab completion
Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast  = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}
