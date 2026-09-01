# dev/remove_prints.ps1 - one-off migration: strips bare `print(` lines from the
# noisiest game files. Superseded by debugPrint() usage in the current code;
# kept only for reference. Review the diff before committing anything it changes.

. "$PSScriptRoot\_env.ps1"

$files = @(
    'lib\game\flow_grid_game.dart',
    'lib\game\grid_manager.dart',
    'lib\game\emergency_manager.dart'
)

foreach ($f in $files) {
    $path = Join-Path $ProjectDir $f
    if (Test-Path $path) {
        $content = Get-Content $path
        $filtered = $content | Where-Object { $_ -notmatch '^\s*print\(' }
        $filtered | Set-Content $path -Encoding utf8
        Write-Host "Cleaned: $f"
    }
}
