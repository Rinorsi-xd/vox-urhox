$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/crater-game.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$argsList=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=500','-validate-timeout=110','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-crater-game.lua'))
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $argsList -RedirectStandardOutput ($projectRoot+'/.tmp/crater-game-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/crater-game-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 120){$p.Kill();throw 'Crater game timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw ('Crater exited without report: '+$p.ExitCode)}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary,missing_resources|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Crater gameplay verification failed'}
