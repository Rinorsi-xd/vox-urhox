param(
    [switch]$ExclusiveNativeWindow,
    [string]$ExpectedShellSha='00A2BAAD7631537E60E3497D407776197A28D53A8ADA83BAE9D850072EB9484C',
    [string]$ExpectedVehicleViewSha='CAD959AF7AE69A319CFEF87FF66F5AB797E3A158743AE4378DBFA3CA31CA99CF'
)
$ErrorActionPreference='Stop'
if(-not $ExclusiveNativeWindow){throw 'Root must allocate an exclusive native window before running. Pass -ExclusiveNativeWindow only after that allocation.'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$runtime=Join-Path $projectRoot '.cli/UrhoXRuntime.exe'
if(-not (Test-Path -LiteralPath $runtime)){throw 'Local native Runtime is absent'}
if((Get-FileHash -LiteralPath (Join-Path $projectRoot 'scripts/render/ShellMaterials.lua')).Hash -ne $ExpectedShellSha){throw 'Shell candidate hash does not match the requested frozen candidate'}
if((Get-FileHash -LiteralPath (Join-Path $projectRoot 'scripts/render/VehicleView.lua')).Hash -ne $ExpectedVehicleViewSha){throw 'VehicleView hash does not match the requested frozen candidate'}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/shell-materials-native-'+$stamp)
New-Item -ItemType Directory -Path $evidence|Out-Null
$files=@('scripts/render/ShellMaterials.lua','scripts/render/VehicleView.lua','scripts/render/BuildXray.lua',
    'scripts/render/PartRig.lua','scripts/parts/Materials.lua','scripts/parts/PartAssets.lua',
    'scripts/construction/Blueprint.lua','scripts/construction/Prefab.lua','scripts/combat/CarUnit.lua',
    'scripts/combat/Debris.lua','scripts/render/CombatView.lua','scripts/render/DriveView.lua',
    'assets/Parts/Catalog.json','tools/migration/check-shell-materials-native.lua',
    'tools/migration/verify-shell-materials-native.ps1')
function Get-ProbeHashes{
    $hashes=[ordered]@{}
    foreach($file in $files){$hashes[$file]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $file)).Hash}
    return $hashes
}
$before=Get-ProbeHashes
$manifest=[ordered]@{sourceCommit='b276064942ae09c0227ec28d4cfda1d5ff006455';
    targetCommit=(& git -C $projectRoot rev-parse HEAD);targetBranch=(& git -C $projectRoot branch --show-current);
    scope='Native isolated actual material/view rendering and explicit fixture damage lifecycle. Not public-input combat, Web/mobile, 706d, or full-game performance acceptance.';
    thresholdMs=100;startedUtc=[DateTime]::UtcNow.ToString('o');before=$before}
$manifestPath=Join-Path $evidence 'manifest.json'
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestPath -Encoding utf8
$report=Join-Path $evidence 'result.json';$metrics=Join-Path $evidence 'shell-native.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=mobile','-validate',
    '-validate-frames=630','-validate-timeout=240','-validate-spike-threshold=100',
    ('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-shell-materials-native.lua'),
    ('-shell-native-output='+$metrics),('-shell-native-directory='+$evidence))
$process=Start-Process -FilePath $runtime -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($evidence+'/stdout.txt') -RedirectStandardError ($evidence+'/stderr.txt')
$deadline=[DateTime]::UtcNow.AddSeconds(255)
while(-not $process.WaitForExit(500)){
    if([DateTime]::UtcNow -ge $deadline){$process.Kill();$process.WaitForExit();throw ('Native shell verification timed out; retain evidence: '+$evidence)}
}
$manifest.after=Get-ProbeHashes;$manifest.finishedUtc=[DateTime]::UtcNow.ToString('o');$manifest.runtimeExit=$process.ExitCode
$manifest.changedDuringRun=@($files|Where-Object {$before[$_] -ne $manifest.after[$_]})
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Output $evidence
if($manifest.changedDuringRun.Count){throw 'Production or fixture changed during native run'}
if(-not (Test-Path -LiteralPath $report) -or -not (Test-Path -LiteralPath $metrics)){throw 'Native fixture produced incomplete evidence'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$details=Get-Content -LiteralPath $metrics -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
$details|Select-Object complete,graphicsApi,clonesCreated,clonesDisposed,damage,error,cleanupError|ConvertTo-Json -Depth 5
if(-not $details.complete -or @($details.checks|Where-Object {-not $_.pass}).Count){throw 'Native shell lifecycle assertions failed'}
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Native overall validation did not PASS; do not hide cold-start/render errors or raise the 100 ms gate'}
