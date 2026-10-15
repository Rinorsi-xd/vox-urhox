param([ValidateSet('desktop','mobile')][string]$Quality='desktop')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    $report=$projectRoot+'/docs/migration/evidence/build-menus.json'
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),'-validate','-validate-frames=335','-validate-timeout=90','-validate-spike-threshold=30000',('-validate-test='+$PSScriptRoot+'/check-build-menus.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/build-menus-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/build-menus-err.txt')
    # Match the other PC UI suites' run allowance. This is a correctness run,
    # not a startup-performance pass; keep the original frame-spike threshold.
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 105){$p.Kill();throw 'Build menu verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources,test_issues | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0 -or $r.test_assertions.total -lt 56){throw 'Build menu verification failed'}
} finally {Pop-Location}
