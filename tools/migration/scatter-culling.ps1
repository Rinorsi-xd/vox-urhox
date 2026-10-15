param([int]$SampleFrames=120,[int]$SettleFrames=60,[int]$TimeoutSeconds=240)
$ErrorActionPreference='Stop'
if($SampleFrames -lt 30 -or $SettleFrames -lt 10){throw 'Insufficient steady/settle frames'}
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $root
try {
    $stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
    $out='.tmp/scatter-culling-'+$stamp
    New-Item -ItemType Directory -Path (Join-Path $root $out) | Out-Null
    $provenance=@{}
    foreach($file in @('assets/Scenes/Crater.xml','scripts/scene/Crater.lua','tools/migration/scatter-culling-core.lua','tools/migration/scatter-culling-runtime.lua','.cli/build.json')){
        $provenance[$file]=(Get-FileHash -LiteralPath (Join-Path $root $file) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $request=@{out=$out;sampleFrames=$SampleFrames;settleFrames=$SettleFrames;provenance=$provenance}
    $text=$request|ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText((Join-Path $root '.tmp/scatter-culling-request.json'),$text,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $root ($out+'/request.json')),$text,[Text.UTF8Encoding]::new($false))
    $validationFrames=28*($SampleFrames+$SettleFrames)+2000
    $arguments=@('_minimap_check.lua',('-tapcode_dir='+$root),'-tool_mode','-quality=mobile','-validate',('-validate-frames='+$validationFrames),('-validate-timeout='+$TimeoutSeconds),'-validate-spike-threshold=100',('-validate-test='+$root+'/tools/migration/scatter-culling-runtime.lua'),('-validate-output='+$root+'/'+$out+'/validation.json'),'-log','info')
    $process=Start-Process -FilePath ($root+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $root -WindowStyle Hidden -PassThru -ArgumentList $arguments -RedirectStandardOutput ($root+'/'+$out+'/stdout.log') -RedirectStandardError ($root+'/'+$out+'/stderr.log')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $process.WaitForExit(500)){
        if($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds+10){$process.Kill();throw ('Scatter experiment timeout: '+$out)}
    }
    if(-not(Test-Path (Join-Path $root ($out+'/native.json')))){throw ('No completed native measurement: '+$out)}
    foreach($file in $provenance.Keys){
        if((Get-FileHash -LiteralPath (Join-Path $root $file) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $provenance[$file]){throw ('Experiment input changed during execution: '+$file)}
    }
    node tools/migration/scatter-culling-analyze.cjs $out
    if($LASTEXITCODE -ne 0){throw ('Scatter analysis failed: '+$out)}
    if(-not(Test-Path (Join-Path $root ($out+'/validation.json')))){throw ('Native validator report missing, measurement remains unaccepted: '+$out)}
    Write-Output ('Evidence: '+$out)
    Write-Output 'MEASURED is not performance/visual acceptance. Inspect analysis, validation, stderr and paired screenshots.'
} finally {Pop-Location}
