param([switch]$Check,[string]$Runtime)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $root
try {
    if($Check){node tools/migration/bake-match-map.cjs check;if($LASTEXITCODE -ne 0){throw 'Map bake stale'};return}
    $runtimePath=if($Runtime){(Resolve-Path -LiteralPath $Runtime).Path}else{Join-Path $root '.cli/UrhoXRuntime.exe'}
    $runtimeSource=$runtimePath
    $stagedDependencies=@()
    if($Runtime){
        # SurfaceShader writes beside the executable, independently of -pp.
        # Keep the complete matching runtime resources in a fresh writable copy.
        $runtimeDirectory=Split-Path $runtimeSource -Parent
        $stageRoot=Join-Path $root ('.tmp/minimap-runtime-'+[guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stageRoot|Out-Null
        $sourceFiles=@(Get-Item -LiteralPath $runtimeSource)
        $sourceFiles+=@(Get-ChildItem -LiteralPath $runtimeDirectory -File|Where-Object {$_.Extension -eq '.dll' -or $_.Name -eq 'OfflineShaderCompiler.exe'})
        foreach($directory in @('CoreData','Data','Res')){
            $sourceDirectory=Join-Path $runtimeDirectory $directory
            if(Test-Path -LiteralPath $sourceDirectory){$sourceFiles+=@(Get-ChildItem -LiteralPath $sourceDirectory -Recurse -File)}
        }
        foreach($file in $sourceFiles){
            $relative=$file.FullName.Substring($runtimeDirectory.Length).TrimStart([char[]]'\/')
            $destination=Join-Path $stageRoot $relative
            New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force|Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $destination
            $sourceHash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sourceHash){throw ('Runtime dependency copy mismatch: '+$relative)}
            $stagedDependencies+=@{relativePath=$relative;sha256=$sourceHash;bytes=$file.Length}
        }
        $runtimePath=Join-Path $stageRoot ([IO.Path]::GetFileName($runtimeSource))
        New-Item -ItemType Directory -Path (Join-Path $stageRoot 'ResCache')|Out-Null
    }
    node tools/migration/bake-match-map.cjs prepare $runtimePath
    if($LASTEXITCODE -ne 0){throw 'Map bake preparation failed'}
    $request=Get-Content .tmp/match-map-bake-request.json -Raw|ConvertFrom-Json
    $arguments=@('_minimap_check.lua',('-tapcode_dir='+$root),'-tool_mode','-quality=mobile','-validate','-validate-frames=900','-validate-timeout=180','-validate-spike-threshold=100',('-validate-test='+$root+'/tools/migration/bake-match-map-runtime.lua'),('-validate-output='+$root+'/'+$request.validation),'-log','info')
    if($Runtime){$arguments+=@('-pp',($root+'/.cli/'),'-skip_login','-skip_isolation')}
    $launch=@{runtime=$request.runtime;sourceExecutable=$runtimeSource;dependencies=$stagedDependencies;arguments=$arguments;workingDirectory=$root;startedAt=[DateTime]::UtcNow.ToString('o')}
    $launch|ConvertTo-Json -Depth 10|Set-Content -LiteralPath ($root+'/'+$request.out+'/runtime-launch.json') -Encoding UTF8
    $process=Start-Process -FilePath $runtimePath -WorkingDirectory $root -WindowStyle Hidden -PassThru -ArgumentList $arguments -RedirectStandardOutput ($root+'/'+$request.out+'/stdout.log') -RedirectStandardError ($root+'/'+$request.out+'/stderr.log')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $process.WaitForExit(500)){if($timer.Elapsed.TotalSeconds -gt 190){$process.Kill();throw 'Map bake timeout'}}
    if(-not(Test-Path ($root+'/'+$request.result))){throw ('Native map bake did not finish; see '+$request.out)}
    node tools/migration/bake-match-map.cjs publish
    if($LASTEXITCODE -ne 0){throw 'Map bake publication failed'}
    node tools/migration/bake-match-map.cjs check
    if($LASTEXITCODE -ne 0){throw 'Map bake final check failed'}
} finally {Pop-Location}
