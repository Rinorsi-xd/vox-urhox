param([switch]$ExclusiveNativeWindow)
$ErrorActionPreference='Stop'
if(-not $ExclusiveNativeWindow){throw 'Parent must allocate an exclusive native runtime window; then pass -ExclusiveNativeWindow.'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/damage-native-timing-'+$stamp)
New-Item -ItemType Directory -Path $evidence | Out-Null
$files=@('scripts/combat/CarUnit.lua','scripts/combat/Debris.lua','scripts/construction/Blueprint.lua',
    'scripts/construction/TurretRange.lua','scripts/drive/VehicleSpec.lua','scripts/drive/Vehicle.lua',
    'scripts/drive/TrackWorld.lua','scripts/physics/Space.lua','scripts/render/CombatView.lua',
    'scripts/render/DriveView.lua','scripts/render/VehicleView.lua','scripts/render/JoinedMesh.lua',
    'scripts/parts/PartAssets.lua','assets/Parts/Catalog.json',
    'tools/migration/check-damage-native-timing.lua','tools/migration/verify-damage-native-timing.ps1')
function Get-ProbeHashes {
    $hashes=[ordered]@{}
    foreach($file in $files){$hashes[$file]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $file) -Algorithm SHA256).Hash}
    return $hashes
}
$before=Get-ProbeHashes
$manifest=[ordered]@{source='2b169a9964645f5f346a7158bcb14447f040814a';
    targetBranch=(& git -C $projectRoot branch --show-current);targetCommit=(& git -C $projectRoot rev-parse HEAD);
    platform='Windows native';thresholdMs=100;scope='CPU/native submission only; not GPU, Web, mobile, or M1 acceptance';
    startedUtc=[DateTime]::UtcNow.ToString('o');before=$before}
$manifestPath=Join-Path $evidence 'manifest.json'
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestPath -Encoding utf8
$report=Join-Path $evidence 'result.json'
$metrics=Join-Path $evidence 'damage-timing.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
    '-validate-frames=120','-validate-timeout=150','-validate-spike-threshold=100',
    ('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-damage-native-timing.lua'),
    ('-damage-timing-output='+$metrics))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($evidence+'/stdout.txt') -RedirectStandardError ($evidence+'/stderr.txt')
$deadline=[DateTime]::UtcNow.AddSeconds(160)
while(-not $process.WaitForExit(500)){
    if([DateTime]::UtcNow -ge $deadline){$process.Kill();$process.WaitForExit();throw ('Native damage probe timed out: '+$evidence)}
}
$manifest.after=Get-ProbeHashes
$manifest.finishedUtc=[DateTime]::UtcNow.ToString('o')
$manifest.runtimeExit=$process.ExitCode
$drift=@($files|Where-Object {$before[$_] -ne $manifest.after[$_]})
$manifest.changedDuringRun=$drift
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Output $evidence
if($drift.Count){throw ('Production/test files changed during run: '+($drift -join ', '))}
if(-not (Test-Path -LiteralPath $report) -or -not (Test-Path -LiteralPath $metrics)){throw 'Native probe did not write complete evidence'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$timing=Get-Content -LiteralPath $metrics -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
foreach($fixture in $timing.fixtures){
    foreach($step in $fixture.steps){
        [pscustomobject]@{name=$fixture.name;combat=$fixture.combat;step=$step.kind;parts=$step.partsBefore;
            removed=$step.removed.Count;nativeBuilds=$step.nativeRebuilds;pieces=$step.debrisCreated;
            damageMs=$step.damage.wallMs;flushMs=$step.flush.wallMs;nativeMs=$step.nativeRebuild.wallMs;
            debrisMs=$step.debrisBuild.wallMs;consumeMs=$step.visualConsume.wallMs;updateMs=$step.visualUpdate.wallMs;
            totalMs=$step.total.wallMs;cpuMs=$step.total.cpuMs}|ConvertTo-Json -Compress
    }
}
if(-not $timing.complete -or $result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Native damage timing/functional verification failed; strict 100 ms threshold preserved'}
