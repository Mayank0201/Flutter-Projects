# dev/_env.ps1 - shared environment resolution for the wrapper scripts in dev/.
# Dot-source it from any script in this folder:  . "$PSScriptRoot\_env.ps1"
#
# Provides:
#   $ProjectDir          - the flow_grid repo root (parent of dev/), wherever it is checked out
#   Resolve-SdkTool      - locates 'flutter' / 'dart' without hardcoding an install path
#
# The SDK is taken from PATH. For an install that is not on PATH, set:
#   $env:FLUTTER_ROOT = "C:\path\to\flutter"

$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Resolve-SdkTool {
    param([Parameter(Mandatory = $true)][string]$Name)

    if ($env:FLUTTER_ROOT) {
        $candidate = Join-Path $env:FLUTTER_ROOT "bin\$Name.bat"
        if (Test-Path $candidate) { return $candidate }
        Write-Warning "FLUTTER_ROOT is '$env:FLUTTER_ROOT' but '$candidate' does not exist; falling back to PATH."
    }

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    throw "Could not find '$Name'. Put the Flutter SDK's bin folder on PATH, or set `$env:FLUTTER_ROOT to the SDK root."
}
