$files = Get-ChildItem -Path 'lib' -Filter '*.dart' -Recurse
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw
    $newContent = $content -replace 'stage1_Ideal','stage1Ideal' -replace 'stage2_Relaxed','stage2Relaxed' -replace 'stage3_MoreRelaxed','stage3MoreRelaxed' -replace 'stage4_StrongRelax','stage4StrongRelax' -replace 'stage5_ExtremeRelax','stage5ExtremeRelax'
    if ($content -ne $newContent) {
        Set-Content $f.FullName $newContent -Encoding utf8
        Write-Host "Updated: $($f.Name)"
    }
}
