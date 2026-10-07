param([string]$Quality='mobile',[switch]$StartBuild)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot 'docs/migration/evidence/build-session.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',('-quality='+$Quality),
    '-validate-frames=345','-validate-timeout=110','-validate-spike-threshold=30000','-x','1280','-y','800',
    ('-validate-test='+$PSScriptRoot+'/check-build-session.lua'),('-validate-output='+$report),'-log','info')
if($StartBuild){$runtimeArgs+='-build'}
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/build-session-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/build-session-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 125){$p.Kill();throw 'Build session verification timeout'}}
$r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$r | Select-Object result,test_result,test_assertions,summary,missing_resources,test_issues | ConvertTo-Json -Depth 6
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Build session verification failed'}
