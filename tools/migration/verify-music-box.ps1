param([ValidateSet('pc')][string]$Case='pc')
$ErrorActionPreference='Stop'
$voxRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
# This native Runtime ignores startup dimensions. Responsive acceptance uses Web.
$sizes=@{'pc'=@(1920,1080)}
$voxReport=$voxRoot+'/docs/migration/evidence/music-box-'+$Case+'.json'
$voxArgs=@('main.lua',('-tapcode_dir='+$voxRoot),'-tool_mode','-validate','-validate-frames=190','-validate-timeout=80','-validate-spike-threshold=2000',('-music-case='+$Case),
    ('-validate-test='+$PSScriptRoot+'/check-music-box.lua'),('-validate-output='+$voxReport),'-x',$sizes[$Case][0],'-y',$sizes[$Case][1])
$voxRun=Start-Process -FilePath ($voxRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $voxRoot -WindowStyle Hidden -PassThru -ArgumentList $voxArgs -RedirectStandardOutput ($voxRoot+'/.tmp/music-box-'+$Case+'-out.txt') -RedirectStandardError ($voxRoot+'/.tmp/music-box-'+$Case+'-err.txt')
if(-not $voxRun.WaitForExit(95000)){$voxRun.Kill();throw 'Music verification timeout'}
$r=Get-Content -LiteralPath $voxReport -Raw -Encoding UTF8 | ConvertFrom-Json
$r | Select-Object result,test_result,test_assertions,summary,test_issues | ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Music verification failed'}
