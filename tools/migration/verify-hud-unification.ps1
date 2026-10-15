$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
node (Join-Path $PSScriptRoot 'source-hud-unification.cjs')
if($LASTEXITCODE -ne 0){throw 'Frozen HUD source execution failed'}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/hud-unification-'+$stamp)
New-Item -ItemType Directory -Path $evidence | Out-Null
$report=Join-Path $evidence 'result.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-quality=mobile','-validate-frames=24','-validate-timeout=45','-validate-spike-threshold=100',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-hud-unification.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput (Join-Path $evidence 'stdout.log') -RedirectStandardError (Join-Path $evidence 'stderr.log')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 60){$process.Kill();throw 'HUD verification timeout'}}
Copy-Item -Path (Join-Path $projectRoot 'docs/migration/evidence/hud-unification-*.png') -Destination $evidence
if(-not(Test-Path -LiteralPath $report)){throw 'HUD report missing'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
Write-Output $evidence
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'HUD verification failed; original report retained'}
