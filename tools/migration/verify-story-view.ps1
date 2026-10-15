$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskReport=Join-Path $taskRoot 'docs/migration/evidence/story-view-native.json'
$taskArgs=@('main.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate',
    '-validate-frames=90','-validate-timeout=90','-validate-spike-threshold=100',
    ('-validate-output='+$taskReport),'-log','info',('-validate-test='+$PSScriptRoot+'/check-story-view.lua'))
$taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs `
    -RedirectStandardOutput ($taskRoot+'/.tmp/story-view-out.txt') -RedirectStandardError ($taskRoot+'/.tmp/story-view-err.txt')
if(-not $taskProcess.WaitForExit(105000)){$taskProcess.Kill();throw 'Story view native verification timeout'}
if(-not (Test-Path -LiteralPath $taskReport)){throw 'Story view native report missing'}
$taskResult=Get-Content -LiteralPath $taskReport -Raw|ConvertFrom-Json
$taskResult|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'Story view functional verification failed'}
