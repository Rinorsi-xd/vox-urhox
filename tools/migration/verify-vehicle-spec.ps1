$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    node (Join-Path $PSScriptRoot 'source-vehicle-fixtures.mjs')
    if($LASTEXITCODE -ne 0){throw 'Source vehicle fixtures failed'}
    $report=Join-Path $projectRoot 'docs/migration/evidence/vehicle-spec.json'
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $args=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
        '-validate-frames=225','-validate-timeout=90','-validate-spike-threshold=5000',
        ('-validate-test='+$PSScriptRoot+'/check-vehicle-spec.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $args -RedirectStandardOutput ($projectRoot+'/.tmp/vehicle-spec-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/vehicle-spec-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Vehicle spec verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Vehicle spec verification failed'}
} finally {Pop-Location}
