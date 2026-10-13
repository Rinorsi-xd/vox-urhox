$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
node (Join-Path $PSScriptRoot 'source-reticle.cjs')
if($LASTEXITCODE -ne 0){throw 'Frozen reticle fixture failed'}
$report=Join-Path $projectRoot 'docs/migration/evidence/reticle-native.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=465','-validate-timeout=100','-validate-spike-threshold=15000',('-validate-test='+$PSScriptRoot+'/check-reticle.lua'),('-validate-output='+$report),'-log','info')
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/reticle-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/reticle-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Reticle verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Missing reticle report'}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Reticle verification failed'}
