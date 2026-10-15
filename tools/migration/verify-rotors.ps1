$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    node (Join-Path $PSScriptRoot 'source-rotors.mjs')
    if($LASTEXITCODE -ne 0){throw 'Frozen rotor fixtures failed'}
    $report=Join-Path $projectRoot 'docs/migration/evidence/rotors-native.json'
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=desktop','-validate',
        '-validate-frames=490','-validate-timeout=180','-validate-spike-threshold=30000',
        ('-validate-test='+$PSScriptRoot+'/check-rotors.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/rotors-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/rotors-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 195){$p.Kill();throw 'Rotor verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources,test_issues | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Rotor verification failed'}
} finally {Pop-Location}
