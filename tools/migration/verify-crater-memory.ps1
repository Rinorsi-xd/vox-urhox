param([ValidatePattern('^[a-zA-Z0-9-]+$')][string]$Label='current',[switch]$PurgeBakeCache)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$prefix=Join-Path $projectRoot ('.tmp/crater-memory-'+$Label)
$report=$prefix+'.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$argsList=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=1770','-validate-timeout=150','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-memory-label='+$Label),('-validate-test='+$PSScriptRoot+'/check-crater-memory.lua'))
if($PurgeBakeCache){$argsList+='-memory-purge-bakes'}
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $argsList -RedirectStandardOutput ($prefix+'-out.txt') -RedirectStandardError ($prefix+'-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 160){$p.Kill();throw 'Crater memory timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw ('Crater memory missing report: '+$p.ExitCode)}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Crater residency verification failed'}
