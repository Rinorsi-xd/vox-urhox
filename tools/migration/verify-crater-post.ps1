$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $root '.tmp/crater-post.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$arguments=@('main.lua',('-tapcode_dir='+$root),'-tool_mode','-quality=desktop','-validate','-validate-frames=125','-validate-timeout=55','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/probe-crater-post.lua'))
$p=Start-Process -FilePath ($root+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $root -WindowStyle Hidden -PassThru -ArgumentList $arguments -RedirectStandardOutput ($root+'/.tmp/crater-post-out.txt') -RedirectStandardError ($root+'/.tmp/crater-post-err.txt')
if(-not $p.WaitForExit(60000)){$p.Kill();throw 'Crater post probe timeout'}
if(-not(Test-Path -LiteralPath $report)){throw 'Crater post probe did not produce a report'}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Crater post verification failed'}
