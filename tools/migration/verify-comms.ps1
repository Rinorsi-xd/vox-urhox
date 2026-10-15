$ErrorActionPreference='Stop'
$voxRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$voxReport=$voxRoot+'/docs/migration/evidence/comms-native.json'
$voxArgs=@('main.lua',('-tapcode_dir='+$voxRoot),'-tool_mode','-validate','-validate-frames=190','-validate-timeout=100','-validate-spike-threshold=15000',
    ('-validate-test='+$PSScriptRoot+'/check-comms.lua'),('-validate-output='+$voxReport))
$voxRun=Start-Process -FilePath ($voxRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $voxRoot -WindowStyle Hidden -PassThru -ArgumentList $voxArgs -RedirectStandardOutput ($voxRoot+'/.tmp/comms-out.txt') -RedirectStandardError ($voxRoot+'/.tmp/comms-err.txt')
if(-not $voxRun.WaitForExit(115000)){$voxRun.Kill();throw 'Comms verification timeout'}
$r=Get-Content -LiteralPath $voxReport -Raw -Encoding UTF8 | ConvertFrom-Json
$r | Select-Object result,test_result,test_assertions,summary,test_issues | ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Comms verification failed'}
