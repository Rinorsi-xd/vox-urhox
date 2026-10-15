param([Parameter(Mandatory=$true)][string]$Python)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/environment-cache.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$argsList=@('dev/CraterPreview.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=300','-validate-timeout=100','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-environment-cache.lua'))
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $argsList -RedirectStandardOutput ($projectRoot+'/.tmp/environment-cache-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/environment-cache-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Environment cache validation timeout'}}
if(-not(Test-Path -LiteralPath $report)){throw ('Missing cache report: '+$p.ExitCode)}
$r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$r|Select-Object result,test_result,test_assertions,summary|ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Environment cache rendering failed'}
& $Python (Join-Path $PSScriptRoot 'check-environment-cache-pixels.py')
if($LASTEXITCODE -ne 0){throw 'Environment cache visual regression'}
