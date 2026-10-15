param([Parameter(Mandatory=$true)][string]$Python)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
& $Python (Join-Path $PSScriptRoot 'check-crater-direct-pixels.py') --fixtures
if($LASTEXITCODE -ne 0){throw 'Direct light fixtures failed'}
$report=Join-Path $projectRoot 'docs/migration/evidence/crater-direct-light.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$argsList=@('dev/CraterPreview.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=300','-validate-timeout=100','-validate-spike-threshold=30000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-crater-direct-light.lua'))
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $argsList -RedirectStandardOutput ($projectRoot+'/.tmp/crater-direct-light-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/crater-direct-light-err.txt')
if(-not $p.WaitForExit(110000)){$p.Kill();throw 'Direct light verification timeout'}
if(-not(Test-Path -LiteralPath $report)){throw ('Missing direct light report: '+$p.ExitCode)}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Direct light rendering failed'}
& $Python (Join-Path $PSScriptRoot 'check-crater-direct-pixels.py')
if($LASTEXITCODE -ne 0){throw 'Direct light pixel verification failed'}
