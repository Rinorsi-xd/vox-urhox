param([ValidateSet('desktop','mobile')][string]$Quality='desktop')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
node (Join-Path $PSScriptRoot 'source-combat-presentation.mjs')
if($LASTEXITCODE -ne 0){throw 'Original H5 presentation fixture failed'}
$report=Join-Path $projectRoot ('docs/migration/evidence/combat-presentation-'+$Quality+'.json')
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$argsList=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),'-validate','-validate-frames=175','-validate-timeout=100','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-combat-presentation.lua'))
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $argsList -RedirectStandardOutput ($projectRoot+'/.tmp/combat-presentation-'+$Quality+'-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/combat-presentation-'+$Quality+'-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Combat presentation verification timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw ('Missing combat presentation report: '+$p.ExitCode)}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary,missing_resources|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Combat presentation verification failed'}
