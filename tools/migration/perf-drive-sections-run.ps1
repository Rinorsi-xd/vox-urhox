param(
 [ValidateSet('baseline','sections')][string]$Mode='sections',
 [string]$Label='sections-1',
 [ValidateSet('lanes','crater')][string]$Scenario='lanes',
 [ValidateSet(0,1)][int]$Firing=0,
 [ValidateSet(0,1)][int]$Ai=1,
 [string]$ProbeDirectory='.tmp/perf-drive-sections-20261016-ready',
 [string]$RuntimePath='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=(Resolve-Path (Join-Path $projectRoot $ProbeDirectory)).Path
$allowedRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp'))+[IO.Path]::DirectorySeparatorChar
if(!$probeRoot.StartsWith($allowedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Probe must be inside workspace .tmp.'}
if($Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid evidence label.'}
$outputPath=Join-Path $probeRoot ($Label+'.json')
if(Test-Path -LiteralPath $outputPath){throw 'Output exists; preserve evidence and choose a new label.'}
$identity=Get-Content (Join-Path $probeRoot 'source-identity.json') -Raw | ConvertFrom-Json
foreach($entry in $identity.variantHashes.PSObject.Properties){
 if((Get-FileHash -LiteralPath (Join-Path $probeRoot $entry.Name) -Algorithm SHA256).Hash.ToLower() -ne $entry.Value){throw ('Probe variant drift: '+$entry.Name)}
}
foreach($entry in $identity.sourceHashes.PSObject.Properties){
 $path=Join-Path $probeRoot $entry.Name
 if($entry.Name -eq 'scripts/drive/LegGait.lua'){$path=Join-Path $probeRoot 'LegGait-baseline.lua'}
 if($entry.Name -eq 'scripts/drive/ContactControl.lua'){$path=Join-Path $probeRoot 'ContactControl-baseline.lua'}
 # UTF-8 decoding/newline normalization is permitted only for the two generated copies.
 if($entry.Name -notin @('scripts/drive/LegGait.lua','scripts/drive/ContactControl.lua') -and (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() -ne $entry.Value){throw ('Snapshot drift: '+$entry.Name)}
}
foreach($name in @('LegGait','ContactControl')){
 $suffix=if($Mode -eq 'sections'){'sections'}else{'baseline'}
 Copy-Item -LiteralPath (Join-Path $probeRoot ($name+'-'+$suffix+'.lua')) -Destination (Join-Path $probeRoot ('scripts/drive/'+$name+'.lua'))
}
$entryPoint=if($Scenario -eq 'crater'){'perf-drive-sections-crater.lua'}else{'perf-drive-sections-native.lua'}
$arguments=@($entryPoint,('-tapcode_dir='+$probeRoot),'-pp',(Join-Path $projectRoot '.cli/'),'-tool_mode','-skip_login','-skip_isolation','-graphicsheadless','-quality=desktop','-log','info',('-probe-output='+$outputPath),('-probe-sections='+[int]($Mode -eq 'sections')),('-probe-firing='+$Firing),('-probe-ai='+$Ai))
$launch=@{runtime=(Resolve-Path $RuntimePath).Path;runtimeSha256=(Get-FileHash -LiteralPath $RuntimePath -Algorithm SHA256).Hash.ToLower();mode=$Mode;args=$arguments;sourceIdentity='source-identity.json';boundary='Requires exclusive Native time window. Diagnostic sections include instrumentation overhead; no gameplay FPS comparison.'}
$launch | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.launch.json')) -Encoding UTF8
$process=Start-Process -FilePath $RuntimePath -ArgumentList $arguments -WorkingDirectory $probeRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
Write-Output ('OWN_RUNTIME_PID='+$process.Id+' LABEL='+$Label)
if(!$process.WaitForExit(120000)){$process.Kill();throw 'Own diagnostic Runtime exceeded 120 seconds.'}
if($null -ne $process.ExitCode -and $process.ExitCode -ne 0){throw ('Native exit '+$process.ExitCode)}
$result=Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
if($result.status -ne 'PASS'){throw $result.error}
$result | Select-Object status,sections,wallMs,timingSteps,stats,counts,metadata,population,bodyCounts,mapInitializationMs | ConvertTo-Json -Depth 6
