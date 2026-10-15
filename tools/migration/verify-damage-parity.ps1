$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    & node (Join-Path $PSScriptRoot 'source-damage-parity.mjs')
    if($LASTEXITCODE -ne 0){throw 'Source damage fixture export failed'}
    $report=Join-Path $projectRoot 'docs/migration/evidence/damage-parity-native.json'
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=90','-validate-timeout=60','-validate-spike-threshold=15000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-damage-parity.lua'))
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/damage-parity-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/damage-parity-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 75){$p.Kill();throw 'Damage parity verification timeout'}}
    if(-not(Test-Path -LiteralPath $report)){throw 'Damage parity report missing'}
    $r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
    $r|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Damage parity verification failed'}
} finally {Pop-Location}
