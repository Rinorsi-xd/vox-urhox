$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskReport=Join-Path $taskRoot 'docs/migration/evidence/engine-pit-deck-native.json'
$taskArgs=@('main.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate','-validate-frames=710','-validate-timeout=150','-validate-spike-threshold=100',('-validate-output='+$taskReport),'-log','info',('-validate-test='+$PSScriptRoot+'/check-engine-pit-deck.lua'))
$taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput ($taskRoot+'/.tmp/engine-pit-deck-out.txt') -RedirectStandardError ($taskRoot+'/.tmp/engine-pit-deck-err.txt')
if(-not $taskProcess.WaitForExit(165000)){$taskProcess.Kill();throw 'EnginePit deck native timeout'}
if(-not(Test-Path -LiteralPath $taskReport)){throw 'EnginePit deck report missing'}
$taskResult=Get-Content -LiteralPath $taskReport -Raw|ConvertFrom-Json
$taskResult|Select-Object result,test_result,test_assertions,summary,@{Name='firstIssues';Expression={$_.test_issues|Select-Object -First 6}}|ConvertTo-Json -Depth 5
if($taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'EnginePit deck native verification failed'}
