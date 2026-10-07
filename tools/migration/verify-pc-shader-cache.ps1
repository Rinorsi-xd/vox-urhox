param([Parameter(Mandatory=$true)][string]$Python,[switch]$FullMenus,[switch]$Graphics,[switch]$Crater,[switch]$Parts,[switch]$Legs)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cachePath=[IO.Path]::GetFullPath((Join-Path $projectRoot '.cli/ResCache/shadercache_runtime/dx11'))
$backupPath=[IO.Path]::GetFullPath((Join-Path $projectRoot ('.tmp/pc-shader-cache-backup-'+[guid]::NewGuid().ToString('N'))))
$generatedPath=$backupPath+'-generated'
foreach($targetPath in @($cachePath,$backupPath,$generatedPath)){
    if(-not $targetPath.StartsWith($projectRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Cache isolation target outside project'}
}
Push-Location $projectRoot
$moved=$false
$prepared=$false
$stage='package'
$evidence=Join-Path $projectRoot 'docs/migration/evidence/pc-shader-cache-isolation.json'
$started=[DateTime]::UtcNow.ToString('o')
[ordered]@{result='RUNNING';started_utc=$started;stage=$stage} | ConvertTo-Json | Set-Content -LiteralPath $evidence -Encoding utf8
try {
    & $Python (Join-Path $PSScriptRoot 'stage-pc-shader-cache.py') --check
    if($LASTEXITCODE -ne 0){throw 'PC shader package is stale or incomplete'}
    if(Test-Path -LiteralPath $cachePath){Move-Item -LiteralPath $cachePath -Destination $backupPath;$moved=$true}
    New-Item -ItemType Directory -Path $cachePath | Out-Null
    $prepared=$true
    $stage='hangar'
    & (Join-Path $PSScriptRoot 'probe-shader-cache.ps1') -Label bundle-cold
    $result=Get-Content -LiteralPath docs/migration/evidence/shader-bundle-cold.json -Raw | ConvertFrom-Json
    $menus=$null
    if($FullMenus){
        $stage='build_menus'
        & (Join-Path $PSScriptRoot 'verify-build-menus.ps1') -Quality desktop
        $menus=Get-Content -LiteralPath docs/migration/evidence/build-menus.json -Raw | ConvertFrom-Json
    }
    $graphicsResult=$null
    if($Graphics){
        $stage='graphics'
        & (Join-Path $PSScriptRoot 'verify-graphics.ps1')
        $graphicsResult=Get-Content -LiteralPath docs/migration/evidence/graphics.json -Raw | ConvertFrom-Json
    }
    $craterResult=$null
    if($Crater){
        $stage='crater'
        & (Join-Path $PSScriptRoot 'verify-crater-game.ps1')
        $craterResult=Get-Content -LiteralPath docs/migration/evidence/crater-game.json -Raw | ConvertFrom-Json
    }
    $partsResult=$null
    if($Parts){
        $stage='parts'
        & (Join-Path $PSScriptRoot 'verify-parts.ps1') -Quality desktop
        $partsResult=Get-Content -LiteralPath docs/migration/evidence/parts-desktop.json -Raw | ConvertFrom-Json
    }
    $legResult=$null
    if($Legs){
        $stage='legs'
        & (Join-Path $PSScriptRoot 'verify-leg-trial.ps1') -Blueprint LegT5 -Quality desktop -Screenshot
        $legResult=Get-Content -LiteralPath docs/migration/evidence/leg-trial-LegT5-desktop-walk1.json -Raw | ConvertFrom-Json
    }
    $newFiles=@(Get-ChildItem -LiteralPath $cachePath -File)
    $stage='coverage'
    [ordered]@{started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o');backend='dx11';development_cache_isolated=$true;generated_cache_files=@($newFiles | ForEach-Object {$_.Name});
        result=$result.result;max_frame_time_ms=$result.max_frame_time_ms;duration_ms=$result.duration_ms;
        build_menus=if($menus){[ordered]@{result=$menus.result;assertions=$menus.test_assertions;max_frame_time_ms=$menus.max_frame_time_ms;duration_ms=$menus.duration_ms}}else{$null};
        graphics=if($graphicsResult){[ordered]@{result=$graphicsResult.result;assertions=$graphicsResult.test_assertions;max_frame_time_ms=$graphicsResult.max_frame_time_ms;duration_ms=$graphicsResult.duration_ms}}else{$null};
        crater=if($craterResult){[ordered]@{result=$craterResult.result;assertions=$craterResult.test_assertions;max_frame_time_ms=$craterResult.max_frame_time_ms;duration_ms=$craterResult.duration_ms}}else{$null};
        parts=if($partsResult){[ordered]@{result=$partsResult.result;assertions=$partsResult.test_assertions;max_frame_time_ms=$partsResult.max_frame_time_ms;duration_ms=$partsResult.duration_ms}}else{$null};
        legs=if($legResult){[ordered]@{result=$legResult.result;assertions=$legResult.test_assertions;max_frame_time_ms=$legResult.max_frame_time_ms;duration_ms=$legResult.duration_ms}}else{$null}
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath docs/migration/evidence/pc-shader-cache-isolation.json -Encoding utf8
    if($result.result -ne 'PASS' -or $result.summary.total_errors -ne 0 -or $newFiles.Count -ne 0){throw 'Packaged shader cache did not fully cover the tested hangar path'}
    if($menus -and ($menus.result -ne 'PASS' -or $menus.test_result -ne 'PASSED' -or $menus.summary.total_errors -ne 0 -or $menus.max_frame_time_ms -ge 2000)){throw 'Build-menu cold-cache run failed or still has a frame over 2 seconds'}
    if($graphicsResult -and ($graphicsResult.result -ne 'PASS' -or $graphicsResult.test_result -ne 'PASSED' -or $graphicsResult.summary.total_errors -ne 0 -or $graphicsResult.max_frame_time_ms -ge 2000)){throw 'Graphics cold-cache run failed or still has a frame over 2 seconds'}
    if($craterResult -and ($craterResult.result -ne 'PASS' -or $craterResult.test_result -ne 'PASSED' -or $craterResult.summary.total_errors -ne 0 -or $craterResult.max_frame_time_ms -ge 2000)){throw 'Crater cold-cache run failed or still has a frame over 2 seconds'}
} catch {
    [ordered]@{result='FAIL';started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o');stage=$stage;error=$_.Exception.Message;development_cache_isolated=$prepared} | ConvertTo-Json | Set-Content -LiteralPath $evidence -Encoding utf8
    throw
} finally {
    # Preserve newly compiled binaries as evidence; restore the exact prior cache.
    if(($moved -or $prepared) -and (Test-Path -LiteralPath $cachePath)){
        if(@(Get-ChildItem -LiteralPath $cachePath -Force).Count -gt 0){Move-Item -LiteralPath $cachePath -Destination $generatedPath}
        else {Remove-Item -LiteralPath $cachePath}
    }
    if($moved){Move-Item -LiteralPath $backupPath -Destination $cachePath}
    Pop-Location
}
