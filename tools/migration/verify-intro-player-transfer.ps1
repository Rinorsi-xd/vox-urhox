$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/intro-player-transfer-'+$stamp)
New-Item -ItemType Directory -Path $evidence | Out-Null
$report=Join-Path $evidence 'result.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-quality=mobile','-validate-frames=5','-validate-timeout=120','-validate-spike-threshold=100',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-intro-montage-pool.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput (Join-Path $evidence 'stdout.log') -RedirectStandardError (Join-Path $evidence 'stderr.log')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 135){$process.Kill();throw 'Intro player transfer verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw 'Intro player transfer report missing'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
Write-Output $evidence
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Intro player transfer verification failed; original report retained'}
