$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskStamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$taskOutput=Join-Path $taskRoot ('docs/migration/evidence/salvage-workshop-'+$taskStamp)
New-Item -ItemType Directory -Path $taskOutput | Out-Null
$taskArgs=@('main.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate','-validate-frames=600','-validate-timeout=100','-validate-spike-threshold=100',('-validate-test='+$PSScriptRoot+'/check-salvage-workshop.lua'),('-validate-output='+$taskOutput+'/result.json'),'-log','info')
$taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput ($taskOutput+'/stdout.txt') -RedirectStandardError ($taskOutput+'/stderr.txt')
if(-not $taskProcess.WaitForExit(115000)){$taskProcess.Kill();throw 'Nested workshop verification timeout'}
$taskResult=Get-Content ($taskOutput+'/result.json') -Raw | ConvertFrom-Json
$taskResult|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
Write-Output $taskOutput
if($taskResult.result -ne 'PASS' -or $taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'Nested workshop verification failed; preserve results'}
