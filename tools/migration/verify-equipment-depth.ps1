param([ValidateSet('on','off','inside')][string]$Phase='on',[ValidateSet('Thruster','Hover')][string]$Kind='Thruster')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$suffix=$Kind+'-'+$Phase
$report=$root+'/docs/migration/evidence/equipment-depth-'+$suffix+'.json'
if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
$runtimeArgs=@('main.lua',('-tapcode_dir='+$root),'-tool_mode','-quality=mobile',('-depth-phase='+$Phase),('-volume-kind='+$Kind),
    '-validate','-validate-frames=150','-validate-timeout=60','-validate-spike-threshold=15000',
    ('-validate-test='+$PSScriptRoot+'/check-equipment-depth.lua'),('-validate-output='+$report),'-log','info',
    '-x','960','-y','540','-screenshot-frame=125',('-screenshot='+$root+'/docs/migration/evidence/equipment-depth-'+$suffix+'.png'))
$p=Start-Process -FilePath ($root+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $root -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($root+'/.tmp/equipment-depth-'+$suffix+'-out.txt') -RedirectStandardError ($root+'/.tmp/equipment-depth-'+$suffix+'-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 75){$p.Kill();throw 'Depth verification timeout'}}
$r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$r | Select-Object result,test_result,test_assertions,summary | ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Depth verification failed'}
