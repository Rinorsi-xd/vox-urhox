$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/endless-runtime-native.json'
if(Test-Path -LiteralPath $report){Move-Item -LiteralPath $report -Destination ($report+'.previous-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff'))}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=2110','-validate-timeout=360','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-endless-runtime.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/endless-runtime-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/endless-runtime-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 375){$process.Kill();throw 'Endless runtime verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Endless runtime report missing'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Endless runtime verification failed'}
