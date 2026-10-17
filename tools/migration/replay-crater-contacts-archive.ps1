param(
 [ValidateSet('baseline','production','baseline-full','mesh-isolation')][string]$Variant='production',
 [string]$RuntimePath='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$archive=Join-Path $projectRoot 'docs/migration/evidence/crater-airwall-contacts-2026-10-17'
$probeRoot=Join-Path $projectRoot ('.tmp/crater-contact-replay-'+[guid]::NewGuid().ToString('N'))
$snapshotRoot=Join-Path $probeRoot 'snapshot'
New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
$snapshotVariant=if($Variant -eq 'production'){'production'}else{'baseline'}
Expand-Archive -LiteralPath (Join-Path $archive ($snapshotVariant+'-scripts.zip')) -DestinationPath $snapshotRoot
New-Item -ItemType Junction -Path (Join-Path $snapshotRoot 'assets') -Target (Join-Path $projectRoot 'assets') | Out-Null
if($Variant -ne 'production'){
 Copy-Item -LiteralPath (Join-Path $archive 'probe-crater-contacts-native.lua') -Destination (Join-Path $snapshotRoot 'scripts/probe-crater-contacts-native.lua') -Force
}
$output=Join-Path $probeRoot 'result.json'
$arguments=@('probe-crater-contacts-native.lua',('-tapcode_dir='+$snapshotRoot),'-pp',(Join-Path $projectRoot '.cli/'),'-tool_mode','-skip_login','-skip_isolation','-graphicsheadless','-quality=desktop','-log','info',('-probe-output='+$output))
if($Variant -in @('production','baseline')){$arguments+='-probe-quick=1'}
if($Variant -eq 'production'){$arguments+='-probe-engine-pit=1'}
if($Variant -eq 'mesh-isolation'){$arguments+='-probe-meshes=1'}
$probe=Start-Process -FilePath $RuntimePath -ArgumentList $arguments -WorkingDirectory $snapshotRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot 'stdout.log') -RedirectStandardError (Join-Path $probeRoot 'stderr.log')
Write-Output ('OWN_RUNTIME_PID='+$probe.Id+' OUTPUT='+$output)
if(!$probe.WaitForExit(180000)){$probe.Kill();throw 'Owned probe exceeded 180 seconds.'}
if(!(Test-Path -LiteralPath $output)){throw ('No result: inspect '+$probeRoot)}
$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
$result | Select-Object status,fullProductionBuild,enginePit,error | ConvertTo-Json -Depth 6
if($result.status -ne 'PASS'){throw 'Probe failed; raw evidence retained.'}
$result.paths | Select-Object name,mode,forwardProgress,contactCount,stopStep | ConvertTo-Json
