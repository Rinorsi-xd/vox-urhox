$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskReport=Join-Path $taskRoot 'docs/migration/evidence/map-effect-lifetime-native.json'
$taskArgs=@('main.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate','-validate-frames=405','-validate-timeout=120','-validate-spike-threshold=100',('-validate-output='+$taskReport),'-log','info',('-validate-test='+$PSScriptRoot+'/check-map-effect-lifetime.lua'))
$taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput ($taskRoot+'/.tmp/map-effect-lifetime-out.txt') -RedirectStandardError ($taskRoot+'/.tmp/map-effect-lifetime-err.txt')
if(-not $taskProcess.WaitForExit(135000)){$taskProcess.Kill();throw 'Map effect lifetime timeout'}
$taskResult=Get-Content -LiteralPath $taskReport -Raw|ConvertFrom-Json
$taskResult|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'Map effect lifetime verification failed'}
