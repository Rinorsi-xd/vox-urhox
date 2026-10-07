$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    & 'C:/Program Files/nodejs/node.exe' (Join-Path $PSScriptRoot 'source-trial-metrics.mjs')
    if($LASTEXITCODE -ne 0){throw 'Source metrics fixtures failed'}
    $report=$projectRoot+'/docs/migration/evidence/pc-drive-hud.json'
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=desktop','-validate','-validate-frames=250','-validate-timeout=90','-validate-spike-threshold=30000',('-validate-test='+$PSScriptRoot+'/check-drive-hud.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/drive-hud-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/drive-hud-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 105){$p.Kill();throw 'PC drive HUD verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources,test_issues | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'PC drive HUD verification failed'}
} finally {Pop-Location}

