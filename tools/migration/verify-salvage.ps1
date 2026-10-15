$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/salvage-native.json'
if(Test-Path -LiteralPath $report){Move-Item -LiteralPath $report -Destination ($report+'.previous-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff'))}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-quality=mobile','-validate-frames=1000','-validate-timeout=180','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-salvage.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/salvage-native-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/salvage-native-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 195){$process.Kill();throw 'Salvage verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Salvage report missing'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Salvage verification failed'}
