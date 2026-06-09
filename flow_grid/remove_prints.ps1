$files = @(
    'lib\game\flow_grid_game.dart',
    'lib\game\grid_manager.dart',
    'lib\game\emergency_manager.dart'
)

foreach ($f in $files) {
    $path = Join-Path $PSScriptRoot $f
    if (Test-Path $path) {
        $content = Get-Content $path
        $filtered = $content | Where-Object { $_ -notmatch '^\s*print\(' }
        $filtered | Set-Content $path -Encoding utf8
        Write-Host "Cleaned: $f"
    }
}
