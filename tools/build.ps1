# A Studio web build: analyze, test, build, and pack astudio-web.zip in the
# project root, ready to upload to the astudio.hepius.co document root.
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 [-SkipTests]
param([switch]$SkipTests)
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'app'
Set-Location $app

function Step($name, [scriptblock]$cmd) {
  Write-Output "=== $name"
  & $cmd
  if ($LASTEXITCODE -ne 0) {
    Write-Output "=== FAILED: $name (exit $LASTEXITCODE)"
    exit 1
  }
}

Step 'pub get' { flutter pub get }
Step 'analyze' { flutter analyze --no-fatal-infos }
if (-not $SkipTests) { Step 'test' { flutter test } }
Step 'build web' { flutter build web --release --no-wasm-dry-run --pwa-strategy=none }

# Kill-switch service worker over the empty generated one (Alfam lesson).
Copy-Item (Join-Path $app 'web\flutter_service_worker.js') (Join-Path $app 'build\web\') -Force

# bsdtar zip: forward slashes and dotfiles, which cPanel's unzip needs.
$zip = Join-Path $root 'astudio-web.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Step 'zip' { tar -a -cf $zip -C (Join-Path $app 'build\web') . }
Write-Output ("=== ZIP {0} ({1:N0} bytes)" -f $zip, (Get-Item $zip).Length)
