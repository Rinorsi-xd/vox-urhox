$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/resource-loading.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=1250','-validate-timeout=110','-validate-spike-threshold=5000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-resource-loading.lua'))
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/resource-loading-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/resource-loading-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 120){$p.Kill();throw 'Resource loading test timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw ('Runtime exited without report: '+$p.ExitCode)}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Resource loading verification failed'}
$metricsLine=Get-Content -LiteralPath ($projectRoot+'/.tmp/resource-loading-out.txt') | Where-Object {$_ -match '\[ResourceLoadingMetrics\] (\{.*\})'} | Select-Object -Last 1
if(-not $metricsLine){throw 'Resource loading metrics were not emitted'}
$metricsJson=[regex]::Match($metricsLine,'\[ResourceLoadingMetrics\] (\{.*\})').Groups[1].Value
$metrics=$metricsJson|ConvertFrom-Json
if($r.test_assertions.total -lt 23){throw 'Resource loading assertions did not all run'}
$metrics|ConvertTo-Json|Set-Content -LiteralPath ($projectRoot+'/docs/migration/evidence/resource-loading-metrics.json') -Encoding utf8
$metrics|Select-Object prepare_frames,max_prepare_slice_ms,prepare_budget_ms,prepare_total_ms,stage_max_ms,remote_transport_verified|ConvertTo-Json
