param([ValidateSet('mg','laser','sniper')][string]$Kind='laser',
    [ValidateSet('desktop','mobile')][string]$Quality='desktop',
    [ValidateSet('active','offline','boot')][string]$Phase='active',[switch]$Screenshot,[switch]$FlowCheck)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    node (Join-Path $PSScriptRoot 'source-weapon-effects.mjs')
    if($LASTEXITCODE -ne 0){throw 'Source persistent weapon fixtures failed'}
    $suffix=$Kind+'-'+$Quality+'-'+$Phase
    if($FlowCheck){$suffix+='-flow'}
    $report=Join-Path $projectRoot ('docs/migration/evidence/weapon-effects-'+$suffix+'.json')
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode',('-quality='+$Quality),('-weapon-kind='+$Kind),('-weapon-phase='+$Phase),
        '-validate','-validate-frames=145','-validate-timeout=150','-validate-spike-threshold=30000',
        ('-validate-test='+$PSScriptRoot+'/check-weapon-effects.lua'),('-validate-output='+$report),'-log','info','-x','1280','-y','720')
    if($Screenshot){$runtimeArgs+=@('-screenshot-frame=125',('-screenshot='+$projectRoot+'/docs/migration/evidence/current-weapon-'+$suffix+'.png'))}
    if($FlowCheck){$runtimeArgs+='-weapon-flow-check'}
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/weapon-effects-'+$suffix+'-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/weapon-effects-'+$suffix+'-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 165){$p.Kill();throw 'Weapon effects verification timeout'}}
    if(-not(Test-Path -LiteralPath $report)){throw 'Weapon effects report missing'}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Weapon effects verification failed'}
} finally {Pop-Location}
