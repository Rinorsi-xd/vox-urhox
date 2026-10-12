$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$motion=Join-Path $projectRoot 'scripts/scene/HangarMotion.lua'
$original=[IO.File]::ReadAllBytes($motion)
try {
    $report=Join-Path $projectRoot 'docs/migration/evidence/hotreload.json'
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-dev','-validate',
        '-validate-frames=360','-validate-timeout=90','-validate-spike-threshold=500',
        ('-validate-test='+$PSScriptRoot+'/check-hotreload.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath (Join-Path $projectRoot '.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/hotreload-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/hotreload-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while (-not $p.WaitForExit(1000)) { if ($timer.Elapsed.TotalSeconds -gt 110) { $p.Kill();throw 'Hot reload validation timed out' } }
    $result=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $result | Select-Object result,test_result,test_assertions,summary | ConvertTo-Json -Depth 5
    if ($result.result -ne 'PASS') { throw 'Hot reload validation failed' }
} finally { [IO.File]::WriteAllBytes($motion,$original) }
