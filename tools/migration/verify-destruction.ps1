param([ValidateSet('desktop','mobile')][string]$Quality='desktop',[switch]$Screenshot,
    [ValidateSet('hit','damaged','wreck')][string]$Phase='hit')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    node (Join-Path $PSScriptRoot 'source-damage-fixtures.mjs')
    if($LASTEXITCODE -ne 0){throw 'Source damage fixtures failed'}
    $suffix=if($Phase -eq 'hit'){$Quality}else{$Quality+'-'+$Phase}
    $report=Join-Path $projectRoot ('docs/migration/evidence/destruction-'+$suffix+'.json')
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),('-destruction-phase='+$Phase),'-validate',
        '-validate-frames=185','-validate-timeout=100','-validate-spike-threshold=15000',
        ('-validate-test='+$PSScriptRoot+'/check-destruction.lua'),('-validate-output='+$report),'-log','info')
    if($Screenshot){$runtimeArgs+=@('-screenshot-frame=125',('-screenshot='+$projectRoot+'/docs/migration/evidence/current-destruction-'+$suffix+'.png'))}
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/destruction-'+$suffix+'-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/destruction-'+$suffix+'-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Destruction verification timeout'}}
    if(-not(Test-Path -LiteralPath $report)){throw 'Destruction report missing; inspect runtime logs'}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Destruction verification failed'}
} finally {Pop-Location}
