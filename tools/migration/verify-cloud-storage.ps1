$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $taskRoot 'docs/migration/evidence/cloud-storage.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-quality=desktop','-validate','-validate-frames=70','-validate-timeout=80','-validate-spike-threshold=30000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-cloud-storage.lua'))
$process=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($taskRoot+'/.tmp/cloud-storage-out.txt') -RedirectStandardError ($taskRoot+'/.tmp/cloud-storage-err.txt')
if(-not $process.WaitForExit(90000)){$process.Kill();throw 'Cloud storage verification timeout'}
if(-not(Test-Path -LiteralPath $report)){throw 'Missing cloud storage report'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Cloud storage verification failed'}
