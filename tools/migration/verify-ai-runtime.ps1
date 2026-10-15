$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/ai-runtime-native.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=1610','-validate-timeout=200','-validate-spike-threshold=100',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-ai-runtime.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/ai-live-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/ai-live-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 215){$process.Kill();throw 'AI runtime verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'AI runtime report missing'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.test_result -ne 'PASSED' -or $result.summary.lua_errors -ne 0 -or $result.summary.resource_errors -ne 0){throw 'AI runtime verification failed'}
