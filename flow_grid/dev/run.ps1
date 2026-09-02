# dev/run.ps1 - wrapper for `flutter run`.
# Usage:
#   .\dev\run.ps1                      -> flutter run -d chrome --web-port 9494
#   .\dev\run.ps1 web-server           -> same, without auto-launching a browser
#   .\dev\run.ps1 windows              -> desktop run (no --web-port)
#   .\dev\run.ps1 chrome --release     -> trailing args are forwarded to flutter

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)]
    [string]$Device = "chrome",
    [int]$Port = 9494,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Extra
)

. "$PSScriptRoot\_env.ps1"

$flutter = Resolve-SdkTool -Name 'flutter'

Push-Location $ProjectDir
try {
    $runArgs = @('run', '-d', $Device)
    if ($Device -in @('chrome', 'edge', 'web-server')) {
        $runArgs += @('--web-port', "$Port")
    }
    if ($Extra) { $runArgs += $Extra }

    & $flutter @runArgs
} finally {
    Pop-Location
}
