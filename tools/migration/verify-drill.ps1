param([string]$Test='check-drill-cast',[int]$Frames=15,[switch]$Screenshot)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$report=Join-Path $projectRoot ('docs/migration/evidence/'+$Test+'.json')
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=desktop','-validate',
    ('-validate-frames='+$Frames),'-validate-timeout=110','-validate-spike-threshold=15000',
    ('-validate-test='+$PSScriptRoot+'/'+$Test+'.lua'),('-validate-output='+$report),'-log','info')
if($Screenshot){$runtimeArgs+=@('-screenshot-frame=125',('-screenshot='+$projectRoot+'/docs/migration/evidence/'+$Test+'.png'))}
$p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/'+$Test+'-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/'+$Test+'-err.txt')
if(-not $p.WaitForExit(125000)){$p.Kill();throw 'Drill verification timeout'}
if(-not(Test-Path -LiteralPath $report)){throw 'Drill report missing; inspect runtime logs'}
$r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Drill verification failed'}
