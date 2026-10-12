$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=$projectRoot+'/docs/migration/evidence/hangar-panels.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=desktop','-validate','-validate-frames=265','-validate-timeout=120','-validate-spike-threshold=30000',('-validate-test='+$PSScriptRoot+'/check-hangar-panels.lua'),('-validate-output='+$report),'-log','info')
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/hangar-panels-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/hangar-panels-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 140){$p.Kill();throw 'Hall panels verification timeout'}}
$r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$r | Select-Object result,test_result,test_assertions,summary,missing_resources,test_issues | ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Hall panels verification failed'}
