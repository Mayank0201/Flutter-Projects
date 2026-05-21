# dev/analyze.ps1 — wrapper for `dart analyze` against the local SDK install.
# Usage:
#   .\dev\analyze.ps1                        → dart analyze (full project)
#   .\dev\analyze.ps1 lib/game/foo.dart      → analyze a single path
#   .\dev\analyze.ps1 lib/ -- --fatal-infos  → forwards extra args after --

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Targets
)

$flutterBin = "C:\Users\AI Intern\flutter-sdk\flutter\bin"
$projectDir = "C:\Users\AI Intern\Documents\Flutter-Projects\flow_grid"

$env:Path = "$flutterBin;$env:Path"
Set-Location $projectDir

$args = @('analyze')
if ($Targets) { $args += $Targets }

& "$flutterBin\dart.bat" @args
