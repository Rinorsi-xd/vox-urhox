$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $taskRoot 'docs/migration/evidence/scene-backdrop.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-quality=desktop','-validate','-validate-frames=125','-validate-timeout=85','-validate-spike-threshold=30000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-scene-backdrop.lua'))
$process=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($taskRoot+'/.tmp/scene-backdrop-out.txt') -RedirectStandardError ($taskRoot+'/.tmp/scene-backdrop-err.txt')
if(-not $process.WaitForExit(95000)){$process.Kill();throw 'Scene backdrop verification timeout'}
if(-not(Test-Path -LiteralPath $report)){throw 'Missing scene backdrop report'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Scene backdrop verification failed'}
