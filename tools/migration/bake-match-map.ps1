param([switch]$Check)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $root
try {
    if($Check){node tools/migration/bake-match-map.cjs check;if($LASTEXITCODE -ne 0){throw 'Map bake stale'};return}
    node tools/migration/bake-match-map.cjs prepare
    if($LASTEXITCODE -ne 0){throw 'Map bake preparation failed'}
    $request=Get-Content .tmp/match-map-bake-request.json -Raw|ConvertFrom-Json
    $arguments=@('_minimap_check.lua',('-tapcode_dir='+$root),'-tool_mode','-quality=mobile','-validate','-validate-frames=900','-validate-timeout=180','-validate-spike-threshold=100',('-validate-test='+$root+'/tools/migration/bake-match-map-runtime.lua'),('-validate-output='+$root+'/'+$request.validation),'-log','info')
    $process=Start-Process -FilePath ($root+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $root -WindowStyle Hidden -PassThru -ArgumentList $arguments -RedirectStandardOutput ($root+'/'+$request.out+'/stdout.log') -RedirectStandardError ($root+'/'+$request.out+'/stderr.log')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $process.WaitForExit(500)){if($timer.Elapsed.TotalSeconds -gt 190){$process.Kill();throw 'Map bake timeout'}}
    if(-not(Test-Path ($root+'/'+$request.result))){throw ('Native map bake did not finish; see '+$request.out)}
    node tools/migration/bake-match-map.cjs publish
    if($LASTEXITCODE -ne 0){throw 'Map bake publication failed'}
    node tools/migration/bake-match-map.cjs check
    if($LASTEXITCODE -ne 0){throw 'Map bake final check failed'}
} finally {Pop-Location}
