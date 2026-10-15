param([ValidateSet('desktop','mobile')][string]$Quality='desktop')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    $report=Join-Path $projectRoot ('docs/migration/evidence/trial-'+$Quality+'.json')
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),'-validate',
        '-validate-frames=235','-validate-timeout=90','-validate-spike-threshold=5000',
        ('-validate-test='+$PSScriptRoot+'/check-trial.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/trial-'+$Quality+'-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/trial-'+$Quality+'-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 100){$p.Kill();throw 'Trial verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Trial verification failed'}
} finally {Pop-Location}
