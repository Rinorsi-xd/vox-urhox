param([switch]$SkipSource)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    if(-not $SkipSource){& node (Join-Path $PSScriptRoot 'measure-source-mobile-editor.cjs');if($LASTEXITCODE -ne 0){throw 'Source mobile editor measurement failed'}}
    $report=Join-Path $projectRoot 'docs/migration/evidence/mobile-editor-native.json'
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=160','-validate-timeout=90','-validate-spike-threshold=30000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-mobile-editor.lua'))
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/mobile-editor-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/mobile-editor-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew();while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 135){$p.Kill();throw 'Mobile editor verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
    $r|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Mobile editor verification failed'}
} finally {Pop-Location}
