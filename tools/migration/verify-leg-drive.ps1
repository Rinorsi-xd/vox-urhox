$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    node (Join-Path $PSScriptRoot 'source-leg-drive-fixtures.mjs')
    if($LASTEXITCODE -ne 0){throw 'Source leg fixtures failed'}
    $report=Join-Path $projectRoot 'docs/migration/evidence/leg-drive.json'
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=65',
        '-validate-timeout=100','-validate-spike-threshold=60000',('-validate-test='+$PSScriptRoot+'/check-leg-drive.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/leg-drive-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/leg-drive-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Leg drive verification timeout'}}
    if(-not(Test-Path -LiteralPath $report)){throw 'Leg drive report missing'}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Leg drive verification failed'}
} finally {Pop-Location}
