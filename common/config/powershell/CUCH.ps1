# Some of the features of this script is only relevant to Windows Terminal.
# This is best used when using the Windows Terminal as the host,
#   i.e. $PROFILE.AllUsersCurrentHost or $PROFILE.CurrentUserCurrentHost

# Change the default background color of the Windows Terminal Pane
function Set-TerminalBackgroundColor {
  <#
    .SYNOPSIS
        Changes the background color of the current Windows Terminal pane.
    .PARAMETER Color
        A color name. For example:
        - 'Black', 'DarkBlue'
        - A Hex string (e.g., '#000000').
        - No value will set the terminal back to it's default background color
    .INPUTS
        You can use the X11 color naming standard, which is the same list used for CSS
        color names (https://www.w3.org/TR/css-color-4/#named-colors). For example:
        ┌──────────┬────────────────────────────────────────────────────────────────────┐
        │ Category │ Examples                                                           │
        ├──────────┼────────────────────────────────────────────────────────────────────┤
        │ Darks    │ DarkBlue, DarkCyan, DarkRed, DarkMagenta, DarkGreen, DarkSlateGray │
        │ Lights   │ LightBlue, LightGreen, LightSalmon, LightSteelBlue, LightGray      │
        │ Vibrant  │ Firebrick, DeepSkyBlue, Goldenrod, ForestGreen, Tomato, Orchid     │
        │ Grays    │ SlateGray, DimGray, Gainsboro, GhostWhite, Silver                  │
        └──────────┴────────────────────────────────────────────────────────────────────┘
      .NOTES
          This function is known to run into issues with other Terminals, so it has to be
          tested after every version update. For example:
          - This function is ignored on VSCode Terminal sessions when GPU Acceleration is
            set to 'auto' or 'on'
    #>
  param(
    [Parameter(Mandatory = $false)]
    [string]$Color
  )
  if ([string]::IsNullOrWhiteSpace($Color)) {
    $Color = ""
    [Console]::Write("`e]111`a")
  }
  else {
    [Console]::Write("`e]11;$Color`a")
  }
}

# Antigravity Custom Functions
function Get-AgySessions {
  <#
    .SYNOPSIS
    Lists all Antigravity CLI conversations with a friendly preview based on the
    first prompt.
  #>
  Get-ChildItem -Directory "$HOME/.gemini/antigravity-cli/brain" | ForEach-Object {
    $transcript = Join-Path $_.FullName ".system_generated/logs/transcript.jsonl"

    # Only process folders that actually have a transcript
    if (Test-Path $transcript) {
      # Reads the file until the very first USER_INPUT is found (no line limit)
      $firstInput = Get-Content $transcript -ErrorAction SilentlyContinue |
      Select-String '"type":"USER_INPUT"' |
      Select-Object -First 1

      if ($firstInput) {
        # Parse the JSON and extract the text
        $json = $firstInput.Line | ConvertFrom-Json
        $preview = $json.content -replace "`n|`r", " " -replace "</?USER_REQUEST>", ""

        # Truncate slightly so it doesn't flood your screen
        if ($preview.Length -gt 64) {
          $preview = $preview.Substring(0, 64) + "..."
        }
      }

      [PSCustomObject]@{
        LastActive     = $_.LastWriteTime.ToString("MM-dd hh:mm")
        ConversationID = $_.Name
        FriendlyName   = $preview
      }
    }
  } | Sort-Object LastActive -Descending | Format-Table LastActive, ConversationID, FriendlyName -Wrap
}

# Sync Repo
function Sync-Repo {
  <#
    .SYNOPSIS
        Triggers the Rclone-Code-sync scheduled task.
  #>
  if ($IsWindows) {
    schtasks /run /tn Rclone-Code-sync
  }
  elseif ($IsMacOS) {
    # Your Mac equivalent here (e.g., triggering a cron or launchd job)
    Write-Warning "Sync-Repo not fully configured for macOS yet."
  }
}

# Aliases for various Agentic Tools

## Google Antigravity CLI
function agyy { agy --dangerously-skip-permissions $args }

## Claude Code
function claudey { claude --dangerously-skip-permissions --permission-mode dontAsk $args }

##  OpenAI Codex
function codexy { codex --sandbox danger-full-access --ask-for-approval never $args }

# Append to $PSModules to include custom ones
$env:PSModulePath = "$HOME/ps-modules$([System.IO.Path]::PathSeparator)$env:PSModulePath"

# herdr config
$env:HERDR_CONFIG_PATH = "$HOME/.config/herdr/config.toml"
