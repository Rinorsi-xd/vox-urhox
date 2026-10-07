param([Parameter(Mandatory=$true)][string]$Python)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
& $Python (Join-Path $PSScriptRoot 'pack-crater-bakes.py')
if($LASTEXITCODE -ne 0){throw 'Bake atlas candidate packing failed'}
$report=Join-Path $projectRoot 'docs/migration/evidence/crater-bakes-validation.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$argsList=@('dev/CraterPreview.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=300','-validate-timeout=100','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-crater-bakes.lua'))
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $argsList -RedirectStandardOutput ($projectRoot+'/.tmp/crater-bakes-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/crater-bakes-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Bake packing validation timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw ('Missing bake packing report: '+$p.ExitCode)}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Bake atlas rendering failed'}
& $Python (Join-Path $PSScriptRoot 'check-crater-bake-pixels.py')
if($LASTEXITCODE -ne 0){throw 'Bake atlas visual regression'}
