$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$evidence=Join-Path $projectRoot 'docs/migration/evidence'
$logRoot=Join-Path $projectRoot '.tmp'
New-Item -ItemType Directory -Force -Path $evidence,$logRoot | Out-Null
$report=Join-Path $evidence 'validate.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
 '-validate-frames=180','-validate-timeout=120','-validate-spike-threshold=500',
 ('-validate-test='+$PSScriptRoot+'/check-hangar.lua'),('-validate-output='+$report),'-log','info')
$p=Start-Process -FilePath (Join-Path $projectRoot '.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($logRoot+'/hangar-final-out.txt') -RedirectStandardError ($logRoot+'/hangar-final-err.txt')
$timer=[System.Diagnostics.Stopwatch]::StartNew()
while (-not $p.WaitForExit(1000)) { if ($timer.Elapsed.TotalSeconds -gt 150) { $p.Kill(); throw 'Runtime exceeded expected verification duration.' } }
$r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$r | Select-Object result,frames_completed,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
if ($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0) { throw 'Hangar verification failed. Read the report and runtime log.' }
