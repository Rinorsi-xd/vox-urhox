param([string]$RunName=('crater-contacts-'+(Get-Date -Format 'yyyyMMdd-HHmmss')))
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=Join-Path $projectRoot ('.tmp/'+$RunName)
$snapshotRoot=Join-Path $probeRoot 'snapshot'
if(Test-Path -LiteralPath $probeRoot){throw 'Probe output already exists; choose another RunName.'}
New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts') -Destination $snapshotRoot -Recurse
Copy-Item -LiteralPath (Join-Path $projectRoot '.project') -Destination $snapshotRoot -Recurse
New-Item -ItemType Junction -Path (Join-Path $snapshotRoot 'assets') -Target (Join-Path $projectRoot 'assets') | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'probe-crater-contacts-native.lua') -Destination (Join-Path $snapshotRoot 'scripts/probe-crater-contacts-native.lua')
$runtimePath='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
$identity=@{runtime=$runtimePath;runtimeSha256=(Get-FileHash -LiteralPath $runtimePath).Hash;head=(git -C $projectRoot rev-parse HEAD);assets='Current assets junction; full physical map created once before all paths';files=@{}}
foreach($name in @('scripts/drive/Vehicle.lua','scripts/drive/CraterPhysics.lua','scripts/drive/RaySuspension.lua','tools/migration/probe-crater-contacts-native.lua','assets/Crater/Layout.json')){
 $identity.files[$name]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash
}
$identity | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $probeRoot 'identity.json') -Encoding utf8
$output=Join-Path $probeRoot 'result.json'
$arguments=@('probe-crater-contacts-native.lua',('-tapcode_dir='+$snapshotRoot),'-pp',(Join-Path $projectRoot '.cli/'),'-tool_mode','-skip_login','-skip_isolation','-graphicsheadless','-quality=desktop','-log','info',('-probe-output='+$output))
$probe=Start-Process -FilePath $runtimePath -ArgumentList $arguments -WorkingDirectory $snapshotRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot 'stdout.log') -RedirectStandardError (Join-Path $probeRoot 'stderr.log')
Write-Output ('OWN_RUNTIME_PID='+$probe.Id+' OUTPUT='+$output)
if(!$probe.WaitForExit(180000)){$probe.Kill();throw 'Owned contact probe exceeded 180 seconds.'}
if($null -ne $probe.ExitCode -and $probe.ExitCode -ne 0){throw ('Native exit '+$probe.ExitCode)}
if(!(Test-Path -LiteralPath $output)){throw ('No result file. Inspect '+$probeRoot)}
$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
if($result.status -ne 'PASS'){throw ($result | ConvertTo-Json -Depth 5)}
$result.paths | Select-Object name,mode,forwardProgress,contactCount,droppedContacts | ConvertTo-Json -Depth 5
Write-Output ('EVIDENCE='+$probeRoot)
