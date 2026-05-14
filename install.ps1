# WAVE Skill Installer — Windows PowerShell

$dest = "$env:USERPROFILE\.claude\plugins\wave-skill"

Write-Host "Installing WAVE skill to $dest..." -ForegroundColor Cyan

if (Test-Path $dest) {
    Write-Host "Removing existing installation..." -ForegroundColor Yellow
    Remove-Item $dest -Recurse -Force
}

New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item -Path ".\skills" -Destination $dest -Recurse
Copy-Item -Path ".\.claude-plugin" -Destination $dest -Recurse

Write-Host "WAVE skill installed." -ForegroundColor Green
Write-Host "Restart Claude Code to activate." -ForegroundColor White
