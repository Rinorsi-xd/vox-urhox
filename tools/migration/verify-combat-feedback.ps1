$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
node (Join-Path $PSScriptRoot 'source-combat-feedback.mjs')
if($LASTEXITCODE -ne 0){throw 'Frozen recovery fixture failed'}
$report=Join-Path $projectRoot 'docs/migration/evidence/combat-feedback-native.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=665','-validate-timeout=130','-validate-spike-threshold=15000',('-validate-test='+$PSScriptRoot+'/check-combat-feedback.lua'),('-validate-output='+$report),'-log','info')
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/combat-feedback-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/combat-feedback-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 140){$p.Kill();throw 'Combat feedback verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Missing combat feedback report'}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Combat feedback verification failed'}
