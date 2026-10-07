$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    node (Join-Path $PSScriptRoot 'source-build-fixtures.mjs')
    if($LASTEXITCODE -ne 0){throw 'Source build fixtures failed'}
    $report=Join-Path $projectRoot 'docs/migration/evidence/build-core.json'
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
        '-validate-frames=65','-validate-timeout=110','-validate-spike-threshold=30000',
        ('-validate-test='+$PSScriptRoot+'/check-build-core.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/build-core-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/build-core-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 125){$p.Kill();throw 'Build core verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Build core verification failed'}
    node (Join-Path $PSScriptRoot 'check-native-build-codes.mjs')
    if($LASTEXITCODE -ne 0){throw 'Original H5 rejected native blueprint exports'}
} finally {Pop-Location}
