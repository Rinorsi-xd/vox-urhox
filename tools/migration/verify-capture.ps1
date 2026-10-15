$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
node (Join-Path $PSScriptRoot 'source-capture.mjs')
if($LASTEXITCODE -ne 0){throw 'Frozen capture reference failed'}
$report=Join-Path $projectRoot 'docs/migration/evidence/capture-native.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=1510','-validate-timeout=200','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-capture.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/capture-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/capture-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 215){$process.Kill();throw 'Capture verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Capture report missing'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Capture verification failed'}
