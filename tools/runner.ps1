# A Studio build runner
#
# Lets Claude run the project's build commands (flutter pub get, analyze,
# test, build web, packaging) on this PC while this window stays open.
# Claude writes a job file into "A Studio\.runner\job.ps1"; this window
# runs it from the project folder and writes the output to
# ".runner\out.txt". Nothing runs unless a job file appears there.
#
# Close this window at any time to stop it.

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root '.runner'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$job = Join-Path $dir 'job.ps1'
$running = Join-Path $dir 'running.ps1'
$out = Join-Path $dir 'out.txt'
$status = Join-Path $dir 'status.txt'
Set-Content -Path $status -Value 'idle' -Encoding ASCII
$Host.UI.RawUI.WindowTitle = 'A Studio runner (close this window to stop)'
Write-Host ''
Write-Host '  A Studio runner is ON.' -ForegroundColor Green
Write-Host "  Watching $dir"
Write-Host '  Close this window to stop it.'
Write-Host ''
while ($true) {
  if (Test-Path $job) {
    Start-Sleep -Milliseconds 800
    Move-Item -Force $job $running
    $first = Get-Content $running -TotalCount 1
    $id = 'job'
    if ($first -match '#\s*job:\s*(\S+)') { $id = $Matches[1] }
    Set-Content -Path $status -Value "running $id" -Encoding ASCII
    Write-Host ("{0}  running {1}" -f (Get-Date -Format 'HH:mm:ss'), $id)
    Push-Location $root
    cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$running`" > `"$out`" 2>&1"
    $code = $LASTEXITCODE
    Pop-Location
    Set-Content -Path $status -Value "done $id $code" -Encoding ASCII
    Write-Host ("{0}  finished {1} (exit {2})" -f (Get-Date -Format 'HH:mm:ss'), $id, $code)
  }
  Start-Sleep -Seconds 2
}
