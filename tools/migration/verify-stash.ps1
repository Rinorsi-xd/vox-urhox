$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/stash-native.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=35','-validate-timeout=90','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-stash.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/stash-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/stash-err.txt')
if(-not $process.WaitForExit(100000)){$process.Kill();throw 'Stash verification timeout'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Stash verification failed'}
