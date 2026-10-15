$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    node (Join-Path $PSScriptRoot 'source-panel-fixtures.mjs')
    if($LASTEXITCODE -ne 0){throw 'Panel source fixture failed'}
    $report=Join-Path $projectRoot 'docs/migration/evidence/panel-session.json'
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=desktop','-validate',
        '-validate-frames=700','-validate-timeout=110','-validate-spike-threshold=30000','-x','1600','-y','900',
        ('-validate-test='+$PSScriptRoot+'/check-panel-session.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/panel-session-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/panel-session-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 125){$p.Kill();throw 'Panel session timeout'}}
    if(-not(Test-Path -LiteralPath $report)){throw ('Panel session exited without report: '+$p.ExitCode)}
    $r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
    $r|Select-Object result,test_result,test_assertions,summary,missing_resources,test_issues|ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Panel session failed'}
} finally {Pop-Location}
