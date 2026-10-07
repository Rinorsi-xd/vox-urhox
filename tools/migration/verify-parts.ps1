param([ValidateSet('desktop','mobile')][string]$Quality='desktop')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    node (Join-Path $PSScriptRoot 'source-parts-fixtures.mjs')
    if($LASTEXITCODE -ne 0){throw 'Source fixtures failed'}
    $report=Join-Path $projectRoot ('docs/migration/evidence/parts-'+$Quality+'.json')
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $partCount=(Get-Content ($projectRoot+'/assets/Parts/Catalog.json') -Raw|ConvertFrom-Json).parts.Count
    $args=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),'-validate',
        ('-validate-frames='+($partCount+70)),'-validate-timeout=150','-validate-spike-threshold=2000',
        ('-validate-test='+$PSScriptRoot+'/check-parts.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $args -RedirectStandardOutput ($projectRoot+'/.tmp/parts-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/parts-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 170){$p.Kill();throw 'Parts verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Parts verification failed'}
} finally {Pop-Location}
