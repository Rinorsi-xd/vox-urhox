param([ValidateSet('LegT3','LegT5','LegWaveT5')][string]$Blueprint='LegT3',
    [ValidateSet('desktop','mobile')][string]$Quality='mobile',
    [ValidateSet('idle','walk1','walk2','walk3','jump','wall')][string]$Phase='walk1',[switch]$Screenshot)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    $suffix=$Blueprint+'-'+$Quality+'-'+$Phase
    $report=Join-Path $projectRoot ('docs/migration/evidence/leg-trial-'+$suffix+'.json')
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),('-blueprint=Blueprints/'+$Blueprint+'.json'),('-leg-phase='+$Phase),
        '-validate','-validate-frames=185','-validate-timeout=100','-validate-spike-threshold=30000',
        ('-validate-test='+$PSScriptRoot+'/check-leg-trial.lua'),('-validate-output='+$report),'-log','info')
    if($Screenshot){$runtimeArgs+=@('-screenshot-frame=125',('-screenshot='+$projectRoot+'/docs/migration/evidence/current-leg-'+$suffix+'.png'))}
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/leg-trial-'+$suffix+'-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/leg-trial-'+$suffix+'-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Leg trial verification timeout'}}
    if(-not(Test-Path -LiteralPath $report)){throw 'Leg trial report missing'}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Leg trial verification failed'}
} finally {Pop-Location}
