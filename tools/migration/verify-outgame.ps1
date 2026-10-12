param([ValidateSet('desktop','mobile')][string]$Quality='desktop')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=$projectRoot+'/docs/migration/evidence/outgame-'+$Quality+'.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),'-validate',
    '-validate-frames=545','-validate-timeout=160','-validate-spike-threshold=2000',
    ('-validate-test='+$PSScriptRoot+'/check-outgame.lua'),('-validate-output='+$report),'-log','info')
if($Quality -eq 'mobile'){$runtimeArgs+=@('-touch','-x','840','-y','378')}
else{$runtimeArgs+=@('-x','1920','-y','1080')}
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/outgame-'+$Quality+'-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/outgame-'+$Quality+'-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 175){$p.Kill();throw 'Outgame verification timeout'}}
$r=Get-Content -LiteralPath $report -Raw -Encoding UTF8 | ConvertFrom-Json
$r | Select-Object result,test_result,test_assertions,summary,missing_resources,test_issues | ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Outgame verification failed'}
