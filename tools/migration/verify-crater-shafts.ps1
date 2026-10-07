$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $root '.tmp/crater-shafts.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$arguments=@('dev/CraterPreview.lua',('-tapcode_dir='+$root),'-tool_mode','-validate','-validate-frames=360','-validate-timeout=55','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/probe-crater-shafts.lua'))
$p=Start-Process -FilePath ($root+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $root -WindowStyle Hidden -PassThru -ArgumentList $arguments -RedirectStandardOutput ($root+'/.tmp/crater-shafts-out.txt') -RedirectStandardError ($root+'/.tmp/crater-shafts-err.txt')
if(-not $p.WaitForExit(60000)){$p.Kill();throw 'Shaft probe timeout'}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Shaft probe failed'}

