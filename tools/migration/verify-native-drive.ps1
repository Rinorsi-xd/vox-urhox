$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    $report=Join-Path $projectRoot 'docs/migration/evidence/native-drive.json'
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $args=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
        '-validate-frames=65','-validate-timeout=90','-validate-spike-threshold=5000',
        ('-validate-test='+$PSScriptRoot+'/check-native-drive.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $args -RedirectStandardOutput ($projectRoot+'/.tmp/native-drive-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/native-drive-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 110){$p.Kill();throw 'Native drive verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Native drive verification failed'}
} finally {Pop-Location}
