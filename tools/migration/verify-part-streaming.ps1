$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=$projectRoot+'/docs/migration/evidence/part-streaming-native.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=desktop','-validate',
    '-validate-frames=75','-validate-timeout=90','-validate-spike-threshold=2000',
    ('-validate-test='+$PSScriptRoot+'/check-part-streaming.lua'),('-validate-output='+$report),'-log','info')
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/part-streaming-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/part-streaming-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 105){$p.Kill();throw 'Part streaming verification timeout'}}
$r=Get-Content -LiteralPath $report -Raw -Encoding UTF8 | ConvertFrom-Json
$r | Select-Object result,test_result,test_assertions,summary,missing_resources,test_issues | ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Part streaming verification failed'}
