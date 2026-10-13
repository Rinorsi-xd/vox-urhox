param([ValidateSet('desktop','mobile')][string]$Quality='mobile',[string]$Label='baseline')
$ErrorActionPreference='Stop'
if($Label -notmatch '^[\w-]+$'){throw 'Invalid label'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot ('docs/migration/evidence/battle-stress-'+$Quality+'-'+$Label+'.json')
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),('-stress-label='+$Label),'-validate','-validate-frames=3610','-validate-timeout=210','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-battle-stress.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/battle-stress-'+$Quality+'-'+$Label+'-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/battle-stress-'+$Quality+'-'+$Label+'-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 225){$process.Kill();throw 'Battle pressure verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Battle pressure report missing'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Battle pressure verification failed'}
