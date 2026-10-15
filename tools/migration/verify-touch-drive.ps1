param([switch]$SkipSource)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    if(-not $SkipSource){
        & node (Join-Path $PSScriptRoot 'measure-source-touch.cjs')
        if($LASTEXITCODE -ne 0){throw 'Source touch measurement failed'}
    }
    $report=Join-Path $projectRoot 'docs/migration/evidence/touch-drive-native.json'
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=660','-validate-timeout=90','-validate-spike-threshold=30000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-touch-drive.lua'))
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/touch-drive-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/touch-drive-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 105){$p.Kill();throw 'Touch drive verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
    $r|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Touch drive verification failed'}
} finally {Pop-Location}
