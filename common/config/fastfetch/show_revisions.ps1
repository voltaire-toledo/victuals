<#
.SYNOPSIS
    Previews each generated ANSI (.ans) file in the current directory with its filename.
#>

[CmdletBinding()]
param(
    [string]$Pattern = "jigs_rev*.ans"
)

# Set console output encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$files = Get-ChildItem -Path . -Filter $Pattern | Sort-Object Name

if (-not $files -or $files.Count -eq 0) {
    $files = Get-ChildItem -Path . -Filter "*.ans" | Sort-Object Name
}

if (-not $files -or $files.Count -eq 0) {
    Write-Warning "No .ans files found in $(Get-Location)"
    return
}

foreach ($file in $files) {
    Write-Host ""
    Write-Host ("-" * 45) -ForegroundColor DarkGray
    Write-Host "  $($file.Name)" -ForegroundColor Cyan
    Write-Host ("-" * 45) -ForegroundColor DarkGray
    
    # Read raw bytes and decode as UTF-8 for exact ANSI escape rendering
    $rawText = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    [Console]::Out.Write($rawText)
    
    if (-not $rawText.EndsWith("`n")) {
        Write-Host ""
    }
}
Write-Host ""
