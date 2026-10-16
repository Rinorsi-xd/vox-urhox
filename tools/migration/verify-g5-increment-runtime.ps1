param([string]$Snapshot='.tmp/outgame-cached-1792077192303')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskSnapshot=(Resolve-Path (Join-Path $taskRoot $Snapshot)).Path
$taskIdentity=Get-Content (Join-Path $taskSnapshot 'identity.json') -Raw|ConvertFrom-Json
if([IO.Path]::GetFileNameWithoutExtension($taskIdentity.manifest_path) -ne 'manifest-2c911f96'){throw 'Unexpected frozen package manifest'}
$taskPaths=@('scripts/endless/Edit.lua','scripts/ui/EndlessEditBar.lua','scripts/salvage/Run.lua','scripts/salvage/RunRules.lua','scripts/salvage/Loot.lua','scripts/ui/SalvageLootMotion.lua','scripts/ui/TouchDriveControls.lua')
$taskHashes=@{}
foreach($taskPath in $taskPaths){
    $taskCurrent=(Get-FileHash (Join-Path $taskRoot $taskPath) -Algorithm SHA256).Hash
    $taskFrozen=(Get-FileHash (Join-Path $taskSnapshot $taskPath) -Algorithm SHA256).Hash
    if($taskCurrent -ne $taskFrozen){throw ('Production differs from frozen package '+$taskPath)}
    $taskHashes[$taskPath]=$taskFrozen
}
$taskOutput=Join-Path $taskRoot ('docs/migration/evidence/g5-increment-manifest-2c911f96-'+[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ'))
New-Item -ItemType Directory -Path $taskOutput|Out-Null
@{identity=$taskIdentity;hashes=$taskHashes;boundary='Native engine with frozen production package scripts and resources. Source starter and controlled test credits/transient/salvage states; real shop and Reset callbacks, real native touch widgets. Not Web, physical touch, natural raid, account or mobile performance evidence.'}|ConvertTo-Json -Depth 50|Set-Content (Join-Path $taskOutput 'identity.json') -Encoding utf8
$taskEscapedOutput=$taskOutput.Replace('\','/')
$taskBootstrap=Join-Path $taskOutput 'fixture.lua'
('VOX_G5_OUTPUT="'+$taskEscapedOutput+'"'+[Environment]::NewLine+'dofile("'+($PSScriptRoot.Replace('\','/'))+'/check-g5-increment-runtime.lua")')|Set-Content $taskBootstrap -Encoding utf8
$taskArgs=@('main.lua',('-tapcode_dir='+$taskSnapshot),'-tool_mode','-validate','-validate-frames=4510','-validate-timeout=240','-validate-spike-threshold=100',('-validate-test='+$taskBootstrap),('-validate-output='+$taskOutput+'/result.json'),'-log','info')
Write-Output ('Evidence: '+$taskOutput)
$taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput ($taskOutput+'/stdout.txt') -RedirectStandardError ($taskOutput+'/stderr.txt')
if(-not $taskProcess.WaitForExit(255000)){$taskProcess.Kill();throw 'G5 increment runtime timeout'}
$taskResult=Get-Content ($taskOutput+'/result.json') -Raw|ConvertFrom-Json
$taskResult|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
if($taskResult.result -ne 'PASS' -or $taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'G5 increment verification failed; preserve results'}
