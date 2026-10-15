$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $root '.tmp/color-pipeline.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$arguments=@('dev/CraterPreview.lua',('-tapcode_dir='+$root),'-tool_mode','-validate','-validate-frames=1700','-validate-timeout=100','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/probe-color-pipeline.lua'))
$p=Start-Process -FilePath ($root+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $root -WindowStyle Hidden -PassThru -ArgumentList $arguments -RedirectStandardOutput ($root+'/.tmp/color-pipeline-out.txt') -RedirectStandardError ($root+'/.tmp/color-pipeline-err.txt')
if(-not $p.WaitForExit(110000)){$p.Kill();throw 'Color pipeline probe timeout'}
if(-not(Test-Path -LiteralPath $report)){throw 'Color probe did not produce a report'}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Color pipeline verification failed'}
