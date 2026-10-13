$ErrorActionPreference='Stop'
$voxRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$voxReport=$voxRoot+'/docs/migration/evidence/livery-native.json'
$voxArgs=@('main.lua',('-tapcode_dir='+$voxRoot),'-tool_mode','-validate','-validate-frames=175','-validate-timeout=80','-validate-spike-threshold=2000',
    ('-validate-test='+$PSScriptRoot+'/check-livery.lua'),('-validate-output='+$voxReport))
$voxRun=Start-Process -FilePath ($voxRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $voxRoot -WindowStyle Hidden -PassThru -ArgumentList $voxArgs -RedirectStandardOutput ($voxRoot+'/.tmp/livery-out.txt') -RedirectStandardError ($voxRoot+'/.tmp/livery-err.txt')
if(-not $voxRun.WaitForExit(95000)){$voxRun.Kill();throw 'Livery verification timeout'}
$r=Get-Content -LiteralPath $voxReport -Raw -Encoding UTF8 | ConvertFrom-Json
$r | Select-Object result,test_result,test_assertions,summary,test_issues | ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Livery verification failed'}
