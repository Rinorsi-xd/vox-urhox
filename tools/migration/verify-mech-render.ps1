param([switch]$Screenshot)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/mech-render-native.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=110','-validate-timeout=90','-validate-spike-threshold=25000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-mech-render.lua'))
if($Screenshot){$runtimeArgs+=@('-screenshot-frame=90',('-screenshot='+$projectRoot+'/docs/migration/evidence/mech-render-native.png'))}
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/mech-render-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/mech-render-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 105){$process.Kill();throw 'Mech render verification timeout'}}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Mech render verification failed'}
