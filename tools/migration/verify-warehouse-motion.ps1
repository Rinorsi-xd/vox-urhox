$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $taskRoot 'docs/migration/evidence/warehouse-motion-native.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-quality=mobile','-validate','-validate-frames=250','-validate-timeout=90','-validate-spike-threshold=30000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-warehouse-motion.lua'))
$process=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($taskRoot+'/.tmp/warehouse-motion-out.txt') -RedirectStandardError ($taskRoot+'/.tmp/warehouse-motion-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 105){$process.Kill();throw 'Warehouse motion verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Missing warehouse motion report'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Warehouse motion verification failed'}
