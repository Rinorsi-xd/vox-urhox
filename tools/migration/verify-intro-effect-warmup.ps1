$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/intro-effect-warmup-native.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-quality=mobile','-validate-frames=50','-validate-timeout=60','-validate-spike-threshold=20000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-intro-effect-warmup.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/intro-effect-warmup-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/intro-effect-warmup-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 75){$process.Kill();throw 'Intro effect warmup verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Intro effect warmup report missing'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Intro effect warmup verification failed'}
