param(
 [switch]$ExclusiveCpuWindow,
 [string]$Label='helper-allocation-1',
 [string]$ProbeDirectory='.tmp/perf-vehicle-allocation-20261017-b',
 [string]$RuntimePath='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
)
$ErrorActionPreference='Stop'
if(!$ExclusiveCpuWindow){throw 'Root must assign an exclusive CPU window before running.'}
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=(Resolve-Path (Join-Path $projectRoot $ProbeDirectory)).Path
$allowedRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp'))+[IO.Path]::DirectorySeparatorChar
if(!$probeRoot.StartsWith($allowedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Probe must stay in workspace .tmp.'}
if($Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid evidence label.'}
$output=Join-Path $probeRoot ($Label+'.json')
if(Test-Path -LiteralPath $output){throw 'Preserve existing evidence; choose another label.'}
$identity=Get-Content (Join-Path $probeRoot 'source-identity.json') -Raw | ConvertFrom-Json
foreach($entry in $identity.sourceHashes.PSObject.Properties){
 if((Get-FileHash -LiteralPath (Join-Path $probeRoot $entry.Name) -Algorithm SHA256).Hash.ToLower() -ne $entry.Value){throw ('Frozen source drift: '+$entry.Name)}
}
$probeHashes=[ordered]@{}
foreach($name in @('perf-vehicle-allocation-native.lua','qa-allocation-owners.lua','qa-native-owner-times.lua')){
 $path=Join-Path $probeRoot ('scripts/'+$name)
 $probeHashes[$name]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
}
$arguments=@('perf-vehicle-allocation-native.lua',('-tapcode_dir='+$probeRoot),'-pp',(Join-Path $projectRoot '.cli/'),'-tool_mode','-skip_login','-skip_isolation','-graphicsheadless','-quality=desktop','-log','info',('-probe-output='+$output))
$launch=@{runtime=$RuntimePath;runtimeSha256=(Get-FileHash -LiteralPath $RuntimePath -Algorithm SHA256).Hash.ToLower();args=$arguments;probeHashes=$probeHashes;sourceIdentity='source-identity.json';boundary='Exclusive headless Native CPU allocation diagnostic. No Web FPS or device acceptance.'}
$launch | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.launch.json')) -Encoding UTF8
$process=Start-Process -FilePath $RuntimePath -ArgumentList $arguments -WorkingDirectory $probeRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
Write-Output ('OWN_RUNTIME_PID='+$process.Id)
if(!$process.WaitForExit(60000)){$process.Kill();throw 'Own diagnostic Runtime exceeded 60 seconds.'}
if($null -ne $process.ExitCode -and $process.ExitCode -ne 0){throw ('Native exit '+$process.ExitCode)}
$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
if($result.status -ne 'PASS'){throw $result.error}
$result | Select-Object status,steps,normalGcSteps,normalGcWallMs,collectorRestored,bodyWrap,batches,metadata,helperTiming | ConvertTo-Json -Depth 6
