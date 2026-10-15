$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff')
$report=Join-Path $projectRoot ('docs/migration/evidence/sound-preparation-'+$stamp+'.json')
$runtimeArgs=@('_minimap_check.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-quality=desktop','-validate-frames=230','-validate-timeout=60','-validate-spike-threshold=100',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-sound-preparation-native.lua'))
$stdout=Join-Path $projectRoot ('.tmp/sound-preparation-'+$stamp+'-out.txt')
$stderr=Join-Path $projectRoot ('.tmp/sound-preparation-'+$stamp+'-err.txt')
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(500)){if($timer.Elapsed.TotalSeconds -gt 75){$process.Kill();throw 'Sound preparation verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw ('Sound preparation report missing; see '+$stdout)}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,max_frame_time_ms|ConvertTo-Json -Depth 5
Select-String -LiteralPath $stdout -Pattern 'SOUND_PREPARATION_NATIVE|VALIDATE_TEST|VALIDATE_ASSERT.*FAIL'
Write-Output $report
if($result.test_result -ne 'PASSED' -or $result.summary.lua_errors -ne 0 -or $result.summary.resource_errors -ne 0){throw 'Sound preparation functional verification failed'}
