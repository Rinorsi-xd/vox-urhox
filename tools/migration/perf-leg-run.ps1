param([switch]$Prepare,[string]$Label='baseline-1',[string]$Mode='baseline',[string]$ProbeDirectory='.tmp/perf-leg-f94827b2')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=Join-Path $projectRoot $ProbeDirectory
$snapshotRoot=Join-Path $probeRoot 'snapshot'
if($Prepare){
 if(Test-Path -LiteralPath $snapshotRoot){throw 'Snapshot already exists.'}
 New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
 $archivePath=Join-Path $probeRoot 'baseline-source.zip'
 & git -C $projectRoot archive --format=zip ('--output='+$archivePath) f94827b26fc12b707e6d6904d093e16358caaf41 scripts .project
 if($LASTEXITCODE -ne 0){throw 'Baseline archive failed.'}
 Expand-Archive -LiteralPath $archivePath -DestinationPath $snapshotRoot
 New-Item -ItemType Junction -Path (Join-Path $snapshotRoot 'assets') -Target (Join-Path $projectRoot 'assets') | Out-Null
 New-Item -ItemType Directory -Path (Join-Path $probeRoot 'before') | Out-Null
 foreach($name in @('LegGait','LegControl','LegHitboxes')){Copy-Item -LiteralPath (Join-Path $snapshotRoot ('scripts/drive/'+$name+'.lua')) -Destination (Join-Path $probeRoot 'before')}
}
if(Test-Path -LiteralPath (Join-Path $probeRoot ($Label+'.json'))){throw 'Output exists; choose a new label to preserve evidence.'}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'perf-leg-native.lua') -Destination (Join-Path $snapshotRoot 'scripts/perf-leg-native.lua')
foreach($name in @('LegGait','LegControl','LegHitboxes')){
 $source=if($Mode -eq 'baseline'){Join-Path $probeRoot ('before/'+$name+'.lua')}else{Join-Path $projectRoot ('scripts/drive/'+$name+'.lua')}
 Copy-Item -LiteralPath $source -Destination (Join-Path $snapshotRoot ('scripts/drive/'+$name+'.lua'))
}
$runtimePath='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
$arguments=@('perf-leg-native.lua',('-tapcode_dir='+$snapshotRoot),'-pp',(Join-Path $projectRoot '.cli/'),'-tool_mode','-skip_login','-skip_isolation','-graphicsheadless','-quality=desktop','-log','info',('-probe-output='+(Join-Path $probeRoot ($Label+'.json'))))
$probe=Start-Process -FilePath $runtimePath -ArgumentList $arguments -WorkingDirectory $snapshotRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
Write-Output ('OWN_RUNTIME_PID='+$probe.Id+' LABEL='+$Label)
if(!$probe.WaitForExit(90000)){$probe.Kill();throw 'Own probe exceeded 90 seconds.'}
if($null -ne $probe.ExitCode -and $probe.ExitCode -ne 0){throw ('Native exit '+$probe.ExitCode)}
$result=Get-Content -LiteralPath (Join-Path $probeRoot ($Label+'.json')) -Raw|ConvertFrom-Json
if($result.status -ne 'PASS'){throw $result.error}
$result|Select-Object status,wallMs,boxOnlyMs,stats,metadata|ConvertTo-Json -Depth 5 -Compress
