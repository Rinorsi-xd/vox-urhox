param([ValidateSet('desktop','mobile')][string]$Quality='desktop',[switch]$Screenshot,
    [ValidateSet('fire','late','clear')][string]$Phase='fire')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    $suffix=if($Phase -eq 'fire'){$Quality}else{$Quality+'-'+$Phase}
    $report=Join-Path $projectRoot ('docs/migration/evidence/combat-'+$suffix+'.json')
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),('-combat-phase='+$Phase),'-validate',
        '-validate-frames=185','-validate-timeout=100','-validate-spike-threshold=15000',
        ('-validate-test='+$PSScriptRoot+'/check-combat.lua'),('-validate-output='+$report),'-log','info')
    if($Screenshot){$runtimeArgs+=@('-screenshot-frame=125',('-screenshot='+$projectRoot+'/docs/migration/evidence/current-combat-'+$suffix+'.png'))}
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/combat-'+$suffix+'-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/combat-'+$suffix+'-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Combat verification timeout'}}
    if(-not(Test-Path -LiteralPath $report)){throw 'Combat report missing; inspect runtime logs'}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Combat verification failed'}
} finally {Pop-Location}
