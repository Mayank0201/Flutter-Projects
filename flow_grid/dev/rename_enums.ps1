# dev/rename_enums.ps1 - one-off migration: renames the PlanningStage enum values
# to lowerCamelCase. Already applied to the tree; kept for reference.

. "$PSScriptRoot\_env.ps1"

$files = Get-ChildItem -Path (Join-Path $ProjectDir 'lib') -Filter '*.dart' -Recurse
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw
    $newContent = $content -replace 'stage1_Ideal','stage1Ideal' -replace 'stage2_Relaxed','stage2Relaxed' -replace 'stage3_MoreRelaxed','stage3MoreRelaxed' -replace 'stage4_StrongRelax','stage4StrongRelax' -replace 'stage5_ExtremeRelax','stage5ExtremeRelax'
    if ($content -ne $newContent) {
        Set-Content $f.FullName $newContent -Encoding utf8
        Write-Host "Updated: $($f.Name)"
    }
}
