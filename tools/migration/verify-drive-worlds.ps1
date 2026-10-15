$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    node tools/migration/source-drive-worlds.mjs
    if($LASTEXITCODE -ne 0){throw 'Actual Rapier source measurement failed'}
    $stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
    $evidence=Join-Path $projectRoot ('docs/migration/evidence/drive-worlds-native-'+$stamp)
    New-Item -ItemType Directory -Path $evidence | Out-Null
    $report=Join-Path $evidence 'result.json'
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=430','-validate-timeout=110','-validate-spike-threshold=30000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-drive-worlds.lua'))
    $process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($evidence+'/stdout.txt') -RedirectStandardError ($evidence+'/stderr.txt')
    if(-not $process.WaitForExit(120000)){$process.Kill();throw 'Actual Bullet world measurement timeout'}
    $result=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $result | Select-Object result,test_result,test_assertions,summary,test_issues | ConvertTo-Json -Depth 5
    if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Bullet world collection failed'}
    node tools/migration/compare-drive-worlds.mjs
    if($LASTEXITCODE -ne 0){throw 'Actual world comparison failed'}
} finally {Pop-Location}
