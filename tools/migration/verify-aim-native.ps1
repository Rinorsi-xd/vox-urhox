$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/aim-assist-native.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=90','-validate-timeout=90','-validate-spike-threshold=100',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-aim-assist.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/aim-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/aim-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 105){$process.Kill();throw 'Aim native verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Aim native report missing'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.test_result -ne 'PASSED' -or $result.summary.lua_errors -ne 0 -or $result.summary.resource_errors -ne 0){throw 'Aim source golden verification failed'}
