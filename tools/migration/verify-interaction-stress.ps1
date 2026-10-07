param([ValidateSet('desktop','mobile')][string]$Quality='desktop')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot ('docs/migration/evidence/interaction-'+$Quality+'.json')
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),'-validate',
 '-validate-frames=1060','-validate-timeout=180','-validate-spike-threshold=2000',
 ('-validate-test='+$PSScriptRoot+'/check-interaction-stress.lua'),('-validate-output='+$report),'-log','info')
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/interaction-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/interaction-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 200){$p.Kill();throw 'Interaction verification timeout; inspect last action in .tmp/interaction-out.txt'}}
if(-not(Test-Path -LiteralPath $report)){throw "No report; exit=$($p.ExitCode). Inspect runtime logs before classifying."}
$r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$r | Select-Object result,frames_completed,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Interaction verification failed'}
