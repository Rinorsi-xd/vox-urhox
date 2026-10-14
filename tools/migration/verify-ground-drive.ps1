$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    node (Join-Path $PSScriptRoot 'source-ground-drive-fixtures.mjs')
    if($LASTEXITCODE -ne 0){throw 'Frozen ground fixtures failed'}
    $evidencePath=Join-Path $projectRoot ('docs/migration/evidence/ground-drive-'+[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ'))
    New-Item -ItemType Directory -Path $evidencePath | Out-Null
    Copy-Item -LiteralPath '.tmp/source-ground-drive-fixtures.json' -Destination ($evidencePath+'/fixtures.json')
    $report=Join-Path $evidencePath 'result.json'
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=65',
        '-validate-timeout=90','-validate-spike-threshold=15000',('-validate-test='+$PSScriptRoot+'/check-ground-drive.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($evidencePath+'/stdout.txt') -RedirectStandardError ($evidencePath+'/stderr.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Ground drive timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    Write-Output $evidencePath
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Ground drive verification failed'}
} finally {Pop-Location}
