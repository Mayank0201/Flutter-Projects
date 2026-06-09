# dev/run.ps1 — wrapper for `flutter run` against the local SDK install.
# Usage:
#   .\dev\run.ps1                  → flutter run -d chrome  --web-port 9494
#   .\dev\run.ps1 web-server       → flutter run -d web-server --web-port 9494 (no auto-launch)
#   .\dev\run.ps1 chrome -- --release  → forwards extra args after --

param(
    [string]$Device = "chrome",
    [int]$Port = 9494,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Extra
)

$flutterBin = "C:\Users\AI Intern\flutter-sdk\flutter\bin"
$projectDir = "C:\Users\AI Intern\Documents\Flutter-Projects\flow_grid"

$env:Path = "$flutterBin;$env:Path"
Set-Location $projectDir

$args = @('run', '-d', $Device, '--web-port', "$Port")
if ($Extra) { $args += $Extra }

& "$flutterBin\flutter.bat" @args
