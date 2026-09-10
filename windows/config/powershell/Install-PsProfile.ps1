<#
.SYNOPSIS
    Installs PS7-CurrentUserAnyHost.ps1 into a PowerShell $PROFILE target
    via dot-source, direct copy, or symbolic link.

.DESCRIPTION
    Interactively asks:
      1) Installation method  (Dot-Source | Copy | Symlink)
      2) Target $PROFILE slot (CurrentUserAllHosts | CurrentUserCurrentHost)

.EXAMPLE
    .\Install-PsProfile.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Resolve source file ──────────────────────────────────────────────────────
$sourceFile = Join-Path $PSScriptRoot 'PS7-CurrentUserAnyHost.ps1'
if (-not (Test-Path -LiteralPath $sourceFile)) {
    Write-Error "Source file not found: $sourceFile`nRun this script from its containing directory."
    exit 1
}

# ── Question 1: Installation method ─────────────────────────────────────────
Write-Host ''
Write-Host 'How would you like to install the profile?' -ForegroundColor Cyan
Write-Host '  [1] Dot-Source  — copy the file next to the target profile and dot-source it'
Write-Host '  [2] Copy        — copy the file directly as the target profile'
Write-Host '  [3] Symlink     — create a symbolic link pointing at the source file'

$methodChoice = Read-Host 'Enter number (or Enter to cancel)'
$method = switch ($methodChoice) {
    '1' { 'DotSource' }
    '2' { 'Copy' }
    '3' { 'Symlink' }
    default { '' }
}
if (-not $method) {
    Write-Host 'Cancelled.' -ForegroundColor Yellow
    exit 0
}

# ── Question 2: Target $PROFILE slot ────────────────────────────────────────
Write-Host ''
Write-Host 'Which $PROFILE slot should be the target?' -ForegroundColor Cyan
Write-Host "  [1] CurrentUserAllHosts    -> $($PROFILE.CurrentUserAllHosts)"
Write-Host "  [2] CurrentUserCurrentHost -> $($PROFILE.CurrentUserCurrentHost)"

$slotChoice = Read-Host 'Enter number (or Enter to cancel)'
$targetPath = switch ($slotChoice) {
    '1' { $PROFILE.CurrentUserAllHosts }
    '2' { $PROFILE.CurrentUserCurrentHost }
    default { '' }
}
if (-not $targetPath) {
    Write-Host 'Cancelled.' -ForegroundColor Yellow
    exit 0
}

$targetDir = Split-Path -Path $targetPath -Parent

# Ensure the target directory exists for all methods
if (-not (Test-Path -LiteralPath $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "  [+]  Created directory: $targetDir" -ForegroundColor DarkGray
}

# ── Execute chosen method ────────────────────────────────────────────────────
switch ($method) {

    'DotSource' {
        # 1. Copy source as dotfiles-ps.ps1 into the same folder as the target profile
        $sidecarPath = Join-Path $targetDir 'dotfiles-ps.ps1'
        Copy-Item -LiteralPath $sourceFile -Destination $sidecarPath -Force
        Write-Host "  [+]  Copied: $sidecarPath" -ForegroundColor Green

        # 2. Append the dot-source line to the target profile (creates the file if absent)
        $dotSourceLine = ". `"$sidecarPath`""
        $alreadyPresent = $false

        if (Test-Path -LiteralPath $targetPath) {
            $existingContent = Get-Content -LiteralPath $targetPath -Raw -ErrorAction SilentlyContinue
            if ($existingContent -and $existingContent.Contains($dotSourceLine)) {
                $alreadyPresent = $true
                Write-Host "  [OK] Dot-source line already present in: $targetPath" -ForegroundColor Green
            }
        }

        if (-not $alreadyPresent) {
            Add-Content -LiteralPath $targetPath -Value "`n$dotSourceLine"
            Write-Host "  [+]  Appended dot-source line to: $targetPath" -ForegroundColor Green
            Write-Host "       Line added: $dotSourceLine" -ForegroundColor DarkGray
        }
    }

    'Copy' {
        # Back up the existing profile before overwriting
        if (Test-Path -LiteralPath $targetPath) {
            $timestamp  = (Get-Date).ToString('yyyyMMdd-HHmmss')
            $backupPath = "$targetPath-$timestamp.bak"
            Rename-Item -LiteralPath $targetPath -NewName $backupPath
            Write-Host "  [~]  Backed up: $targetPath -> $backupPath" -ForegroundColor Yellow
        }

        Copy-Item -LiteralPath $sourceFile -Destination $targetPath -Force
        Write-Host "  [+]  Copied: $targetPath" -ForegroundColor Green
    }

    'Symlink' {
        Write-Host ''
        Write-Host '  IMPORTANT — Symlink requirement:' -ForegroundColor Yellow
        Write-Host "  The source file must be permanently accessible at:" -ForegroundColor Yellow
        Write-Host "    $sourceFile" -ForegroundColor White
        Write-Host '  This means it must be on a local, always-mounted volume.' -ForegroundColor Yellow
        Write-Host '  Do NOT use a network share, VHD/VHDX, RAM disk, or any drive' -ForegroundColor Yellow
        Write-Host '  that may be unavailable when PowerShell starts.' -ForegroundColor Yellow
        Write-Host ''

        $confirm = Read-Host '  Understood — proceed with symlink? [y/N]'
        if ($confirm -ne 'y') {
            Write-Host 'Cancelled.' -ForegroundColor Yellow
            exit 0
        }

        # Back up any existing non-symlink file so it is not silently lost
        if (Test-Path -LiteralPath $targetPath) {
            $existingItem = Get-Item -LiteralPath $targetPath -Force
            if ($existingItem.LinkType -ne 'SymbolicLink') {
                $timestamp  = (Get-Date).ToString('yyyyMMdd-HHmmss')
                $backupPath = "$targetPath-$timestamp.bak"
                Rename-Item -LiteralPath $targetPath -NewName $backupPath
                Write-Host "  [~]  Backed up: $targetPath -> $backupPath" -ForegroundColor Yellow
            } else {
                Remove-Item -LiteralPath $targetPath -Force
            }
        }

        $resolvedSource = (Resolve-Path -LiteralPath $sourceFile).Path
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $resolvedSource -Force | Out-Null
        Write-Host "  [+]  Symlink created:       $targetPath" -ForegroundColor Green
        Write-Host "       -> $resolvedSource" -ForegroundColor DarkGray
    }
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
