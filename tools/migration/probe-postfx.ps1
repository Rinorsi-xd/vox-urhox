param([int]$Frames=55)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=desktop','-validate',('-validate-frames='+$Frames),'-validate-timeout=60','-validate-spike-threshold=2000',('-validate-test='+$PSScriptRoot+'/probe-postfx.lua'),('-validate-output='+$projectRoot+'/.tmp/postfx-probe.json'),'-log','info')
    $p=Start-Process -FilePath .cli/UrhoXRuntime.exe -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput .tmp/postfx-out.txt -RedirectStandardError .tmp/postfx-err.txt
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 75){$p.Kill();throw 'PostFX probe timed out'}}
    $r=Get-Content .tmp/postfx-probe.json -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary | ConvertTo-Json -Depth 5
    if($r.summary.total_errors -ne 0 -or $r.test_assertions.total -lt 1){throw 'PostFX capability probe failed'}
} finally {Pop-Location}
