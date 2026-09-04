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

# Each `flutter run` keeps its build scratch in %LOCALAPPDATA%\Temp\flutter_tools.*
# and removes it on a clean exit. Killing the process instead -- which is what
# happens on every stop-and-rebuild -- orphans the folder, and they are ~350 MB
# each. Sweep the stale ones before launching. The age filter leaves anything a
# running build is still using alone, and a locked folder is skipped rather than
# failing the launch.
Get-ChildItem "$env:LOCALAPPDATA\Temp" -Directory -Filter 'flutter_tools.*' -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddMinutes(-15) } |
    ForEach-Object { try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop } catch { } }

# `flutter run -d chrome` otherwise launches Chrome with a throwaway profile
# inside the very temp folder swept above, so the game's saved cities (which
# live in browser storage) are wiped on every restart. Pin the profile to a
# stable folder next to the repo instead, and keep it out of git.
$chromeProfile = Join-Path $ProjectDir '.dev-chrome-profile'
if (-not (Test-Path $chromeProfile)) { New-Item -ItemType Directory -Path $chromeProfile | Out-Null }

$flutter = Resolve-SdkTool -Name 'flutter'

Push-Location $ProjectDir
try {
    $runArgs = @('run', '-d', $Device)
    if ($Device -in @('chrome', 'edge', 'web-server')) {
        $runArgs += @('--web-port', "$Port")
    }
    # flutter_tools uses a --user-data-dir passed through --web-browser-flag if
    # there is one, and otherwise makes a throwaway profile in the system temp
    # folder (see Chrome._createUserDataDirectory). Point it at the pinned
    # profile so saved cities survive a restart.
    if ($Device -in @('chrome', 'edge')) {
        $runArgs += "--web-browser-flag=--user-data-dir=$chromeProfile"
    }
    if ($Extra) { $runArgs += $Extra }

    & $flutter @runArgs
} finally {
    Pop-Location
}
