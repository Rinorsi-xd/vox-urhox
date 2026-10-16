$ErrorActionPreference='Stop'
$projectRoot='D:/Rino_Project/maker/Vox/VoxelCraft'
$probeRoot=Join-Path $projectRoot '.tmp/monitor-overhead-25149307'
$snapshotRoot=Join-Path $probeRoot 'snapshot'
$conflicts=Get-CimInstance Win32_Process -Filter "Name = 'UrhoXRuntime.exe'" | Where-Object { $_.CommandLine -match '-graphicsheadless' }
if($conflicts){throw 'Another headless measurement is active.'}
if(Test-Path -LiteralPath $snapshotRoot){throw 'Snapshot exists; preserve prior evidence.'}
New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts') -Destination $snapshotRoot -Recurse
Copy-Item -LiteralPath (Join-Path $projectRoot '.project') -Destination $snapshotRoot -Recurse
New-Item -ItemType Junction -Path (Join-Path $snapshotRoot 'assets') -Target (Join-Path $projectRoot 'assets') | Out-Null
Copy-Item -LiteralPath (Join-Path $probeRoot 'probe.lua') -Destination (Join-Path $snapshotRoot 'scripts/monitor-overhead-probe.lua')
$runtimePath='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
foreach($label in @('disabled-1','enabled-1','disabled-2','enabled-2')){
 $mode=if($label.StartsWith('enabled')){'1'}else{'0'}
 $arguments=@('monitor-overhead-probe.lua',('-tapcode_dir='+$snapshotRoot),'-pp',(Join-Path $projectRoot '.cli/'),'-tool_mode','-skip_login','-skip_isolation','-graphicsheadless','-quality=desktop','-log','info',('-probe-enabled='+$mode),('-probe-output='+(Join-Path $probeRoot ($label+'.json'))))
 $probe=Start-Process -FilePath $runtimePath -ArgumentList $arguments -WorkingDirectory $snapshotRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($label+'.stderr.log'))
 Write-Output ('OWN_RUNTIME_PID='+$probe.Id+' LABEL='+$label)
 if(!$probe.WaitForExit(90000)){$probe.Kill();throw 'Own probe exceeded 90 seconds.'}
 if($probe.ExitCode -ne 0){throw ('Native exit '+$probe.ExitCode)}
 $result=Get-Content -LiteralPath (Join-Path $probeRoot ($label+'.json')) -Raw|ConvertFrom-Json
 if($result.status -ne 'PASS'){throw $result.error}
 $result|Select-Object status,enabled,wallMs,clockMs,serializedRecords,serializedBytes|ConvertTo-Json -Compress
}
