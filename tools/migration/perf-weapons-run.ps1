param([string]$RunName='perf-weapons-profile-2026-10-16',[string]$Mode='profile',[string]$Label='baseline',[string]$Snapshot='',[string]$WeaponFile='')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=Join-Path $projectRoot ('.tmp/'+$RunName)
if(Test-Path -LiteralPath (Join-Path $probeRoot ($Label+'.json'))){throw 'Output already exists. Preserve it and choose another run/label.'}
New-Item -ItemType Directory -Path $probeRoot -Force | Out-Null
if(!$Snapshot){
 $Snapshot=Join-Path $probeRoot 'snapshot'
 if(Test-Path -LiteralPath $Snapshot){throw 'Snapshot already exists.'}
 New-Item -ItemType Directory -Path $Snapshot | Out-Null
 Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts') -Destination (Join-Path $Snapshot 'scripts') -Recurse
 Copy-Item -LiteralPath (Join-Path $projectRoot '.project') -Destination (Join-Path $Snapshot '.project') -Recurse
 New-Item -ItemType Junction -Path (Join-Path $Snapshot 'assets') -Target (Join-Path $projectRoot 'assets') | Out-Null
}
$Snapshot=(Resolve-Path -LiteralPath $Snapshot).Path
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'perf-weapons-native.lua') -Destination (Join-Path $Snapshot 'scripts/perf-weapons-native.lua')
if($WeaponFile){Copy-Item -LiteralPath $WeaponFile -Destination (Join-Path $Snapshot 'scripts/combat/WeaponSystem.lua')}
$runtime='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
$identity=@{snapshot=$Snapshot;mode=$Mode;label=$Label;runtime=$runtime;runtimeSha256=(Get-FileHash $runtime -Algorithm SHA256).Hash;probeSha256=(Get-FileHash (Join-Path $Snapshot 'scripts/perf-weapons-native.lua') -Algorithm SHA256).Hash;weaponSha256=(Get-FileHash (Join-Path $Snapshot 'scripts/combat/WeaponSystem.lua') -Algorithm SHA256).Hash;otherRuntimePids=@(Get-Process -Name UrhoXRuntime -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)}
$identity | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $probeRoot ($Label+'.identity.json')) -Encoding utf8
$arguments=@('perf-weapons-native.lua',('-tapcode_dir='+$Snapshot),'-pp',(Join-Path $projectRoot '.cli/'),'-tool_mode','-skip_login','-skip_isolation','-graphicsheadless','-log','info',('-probe-mode='+$Mode),('-probe-label='+$Label),('-probe-output='+(Join-Path $probeRoot ($Label+'.json'))))
$process=Start-Process -FilePath $runtime -ArgumentList $arguments -WorkingDirectory $Snapshot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
Write-Output ('OWN_RUNTIME_PID='+$process.Id+' LABEL='+$Label)
if(!$process.WaitForExit(180000)){$process.Kill();throw 'Own probe exceeded 180 seconds.'}
$process.Refresh();$exitCode=$process.ExitCode
if($null -eq $exitCode){Write-Warning 'WaitForExit completed but ExitCode is unavailable; requiring fresh PASS output and matching run identity.'}
@{pid=$process.Id;waitForExitCompleted=$true;exitCode=$exitCode;exitCodeAvailable=($null -ne $exitCode);arguments=$arguments} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $probeRoot ($Label+'.process.json')) -Encoding utf8
if($null -ne $exitCode -and $exitCode -ne 0){throw ('Runtime failed '+$exitCode)}
$result=Get-Content -LiteralPath (Join-Path $probeRoot ($Label+'.json')) -Raw | ConvertFrom-Json
if($result.status -ne 'PASS'){throw $result.error}
if($result.mode -ne $Mode -or $result.label -ne $Label -or $result.seed -ne 16102026){throw 'Probe identity mismatch.'}
$result.scenarios | Select-Object name,systems,steps,totalMs,counts | ConvertTo-Json -Depth 4
