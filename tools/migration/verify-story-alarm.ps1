$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskReport=Join-Path $taskRoot 'docs/migration/evidence/story-alarm-native.json'
$taskArgs=@('main.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate','-validate-frames=55','-validate-timeout=60','-validate-spike-threshold=100',('-validate-output='+$taskReport),'-log','info',('-validate-test='+$PSScriptRoot+'/check-story-alarm.lua'))
$taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput ($taskRoot+'/.tmp/story-alarm-out.txt') -RedirectStandardError ($taskRoot+'/.tmp/story-alarm-err.txt')
if(-not $taskProcess.WaitForExit(75000)){$taskProcess.Kill();throw 'Story alarm timeout'}
$taskResult=Get-Content -LiteralPath $taskReport -Raw|ConvertFrom-Json
$taskResult|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'Story alarm verification failed'}
