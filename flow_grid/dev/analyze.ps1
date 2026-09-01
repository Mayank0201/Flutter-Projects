# dev/analyze.ps1 - wrapper for `flutter analyze`.
# Usage:
#   .\dev\analyze.ps1                       -> analyze the whole project
#   .\dev\analyze.ps1 lib\game              -> analyze a single path
#   .\dev\analyze.ps1 lib --fatal-infos     -> trailing args are forwarded to flutter

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Targets
)

. "$PSScriptRoot\_env.ps1"

$flutter = Resolve-SdkTool -Name 'flutter'

Push-Location $ProjectDir
try {
    $analyzeArgs = @('analyze')
    if ($Targets) { $analyzeArgs += $Targets }

    & $flutter @analyzeArgs
} finally {
    Pop-Location
}
