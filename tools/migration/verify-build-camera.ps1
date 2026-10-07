param()
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    & 'C:/Program Files/nodejs/node.exe' ($PSScriptRoot+'/source-build-camera.mjs')
    if($LASTEXITCODE -ne 0){throw 'Source camera fixtures failed'}
    $report=$projectRoot+'/docs/migration/evidence/build-camera.json'
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=desktop','-validate','-validate-frames=180','-validate-timeout=95','-validate-spike-threshold=30000',('-validate-test='+$PSScriptRoot+'/check-build-camera.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/build-camera-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/build-camera-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Build camera verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources,test_issues | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0 -or $r.test_assertions.total -lt 350){throw 'Build camera verification failed'}
} finally {Pop-Location}
