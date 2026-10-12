param([ValidatePattern('^[a-zA-Z0-9-]+$')][string]$Label='current')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$prefix=Join-Path $projectRoot ('.tmp/crater-parity-'+$Label)
$report=$prefix+'.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$argsList=@('dev/CraterPreview.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=245','-validate-timeout=100','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-parity-label='+$Label),('-validate-test='+$PSScriptRoot+'/check-crater-parity.lua'))
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $argsList -RedirectStandardOutput ($prefix+'-out.txt') -RedirectStandardError ($prefix+'-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Crater parity render timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw ('Crater exited without report: '+$p.ExitCode)}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary,missing_resources|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Crater parity verification failed'}
