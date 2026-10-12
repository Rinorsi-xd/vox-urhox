param([string]$Label='cache-probe')
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-z0-9-]+$'){throw 'Invalid evidence label'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Force -Path .tmp/shader-cache-probe | Out-Null
    $report=$projectRoot+'/docs/migration/evidence/shader-'+$Label+'.json'
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=desktop','-validate',
        '-validate-frames=65','-validate-timeout=90','-validate-spike-threshold=2000',
        ('-validate-test='+$PSScriptRoot+'/probe-shader-cache.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/shader-'+$Label+'-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/shader-'+$Label+'-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 105){$p.Kill();throw 'Shader probe timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,duration_ms,max_frame_time_ms,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
} finally {Pop-Location}
