param([ValidateRange(1,1024)][int]$Batch=256)
# CPU baseline fixtures were captured before replacing that implementation.
# Keep them immutable; this command verifies the current GPU implementation.
$Label='gpu'
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot ('docs/migration/evidence/crater-dust-'+$Label+'.json')
$out=Join-Path $projectRoot ('.tmp/crater-dust-'+$Label+'-out.txt')
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('dev/CraterPreview.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=300','-validate-timeout=110','-validate-spike-threshold=25000',('-validate-output='+$report),'-log','info','-x','1280','-y','720',('-dust-label='+$Label),('-validate-test='+$PSScriptRoot+'/check-crater-dust.lua'))
$runtimeArgs+=('-dust-batch='+$Batch)
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput $out -RedirectStandardError ($projectRoot+'/.tmp/crater-dust-'+$Label+'-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 120){$p.Kill();throw 'Crater dust verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Crater dust exited without report'}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0 -or $r.test_assertions.total -lt 12){throw 'Crater dust verification failed'}
$line=Get-Content -LiteralPath $out | Where-Object {$_ -match '\[CraterDustMetrics\] (\{.*\})'} | Select-Object -Last 1
if(-not $line){throw 'Crater dust metrics missing'}
$metrics=[regex]::Match($line,'\[CraterDustMetrics\] (\{.*\})').Groups[1].Value|ConvertFrom-Json
$metrics|ConvertTo-Json|Set-Content -LiteralPath ($projectRoot+'/docs/migration/evidence/crater-dust-'+$Label+'-metrics.json') -Encoding utf8
$metrics|ConvertTo-Json
