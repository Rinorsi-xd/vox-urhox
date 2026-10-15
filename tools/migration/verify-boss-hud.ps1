$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskReport=Join-Path $taskRoot 'docs/migration/evidence/boss-hud-native.json'
$taskArgs=@('main.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate','-validate-frames=56','-validate-timeout=30','-validate-spike-threshold=100',('-validate-output='+$taskReport),'-log','info',('-validate-test='+$PSScriptRoot+'/check-boss-hud.lua'))
$taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput ($taskRoot+'/.tmp/boss-hud-out.txt') -RedirectStandardError ($taskRoot+'/.tmp/boss-hud-err.txt')
if(-not $taskProcess.WaitForExit(45000)){$taskProcess.Kill();throw 'Boss HUD timeout'}
$taskResult=Get-Content -LiteralPath $taskReport -Raw|ConvertFrom-Json
$taskResult|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'Boss HUD verification failed'}
