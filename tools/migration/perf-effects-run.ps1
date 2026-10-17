param([string]$RunName='perf-effects-20261017',[ValidateSet('profile','timing','equivalence')][string]$Mode='profile',[string]$Label='baseline',[string]$Snapshot='',[string]$BatchFile='',[string]$EffectsFile='',[string]$RuntimePath='',[string]$ResourcePrefix='')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if($RunName -notmatch '^[A-Za-z0-9_-]+$' -or $Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid run or label.'}
$probeRoot=Join-Path $projectRoot ('.tmp/'+$RunName)
if(Test-Path -LiteralPath (Join-Path $probeRoot ($Label+'.json'))){throw 'Output exists; preserve evidence.'}
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
$allowed=[IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp'))+[IO.Path]::DirectorySeparatorChar
if(!$Snapshot.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Snapshot must be inside workspace .tmp.'}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'perf-effects-native.lua') -Destination (Join-Path $Snapshot 'scripts/perf-effects-native.lua')
if($BatchFile){Copy-Item -LiteralPath $BatchFile -Destination (Join-Path $Snapshot 'scripts/render/EffectBatch.lua')}
if($EffectsFile){Copy-Item -LiteralPath $EffectsFile -Destination (Join-Path $Snapshot 'scripts/render/CombatEffects.lua')}
$runtime=if($RuntimePath){(Resolve-Path -LiteralPath $RuntimePath).Path}else{'D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'}
$resources=if($ResourcePrefix){(Resolve-Path -LiteralPath $ResourcePrefix).Path}else{Join-Path $projectRoot '.cli'}
$hashes=@{}
foreach($entry in Get-ChildItem -LiteralPath (Join-Path $Snapshot 'scripts') -Recurse -File -Filter '*.lua'){
 $relative=$entry.FullName.Substring($Snapshot.Length+1).Replace('\','/')
 $hashes[$relative]=(Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash.ToLower()
}
$resourceHashes=@{}
foreach($directory in @('CoreData','Data','Res')){
 $root=Join-Path $resources $directory
 if(Test-Path -LiteralPath $root){foreach($entry in Get-ChildItem -LiteralPath $root -Recurse -File){$resourceHashes[$directory+'/'+$entry.FullName.Substring($root.Length+1).Replace('\','/')]=(Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash.ToLower()}}
}
@{snapshot=$Snapshot;mode=$Mode;label=$Label;runtime=$runtime;resourcePrefix=$resources;resourceHashes=$resourceHashes;runtimeSha256=(Get-FileHash $runtime -Algorithm SHA256).Hash.ToLower();sourceHashes=$hashes;otherRuntimePids=@(Get-Process -Name UrhoXRuntime -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $probeRoot ($Label+'.identity.json')) -Encoding utf8
$arguments=@('perf-effects-native.lua',('-tapcode_dir='+$Snapshot),'-pp',($resources+'/'),'-tool_mode','-skip_login','-skip_isolation','-quality=desktop','-log','info',('-probe-mode='+$Mode),('-probe-label='+$Label),('-probe-output='+(Join-Path $probeRoot ($Label+'.json'))))
$process=Start-Process -FilePath $runtime -ArgumentList $arguments -WorkingDirectory $Snapshot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
Write-Output ('OWN_RUNTIME_PID='+$process.Id+' LABEL='+$Label)
if(!$process.WaitForExit(180000)){$process.Kill();throw 'Own probe exceeded 180 seconds.'}
$process.Refresh();$exitCode=$process.ExitCode
@{pid=$process.Id;waitForExitCompleted=$true;exitCode=$exitCode;arguments=$arguments} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $probeRoot ($Label+'.process.json')) -Encoding utf8
if($null -ne $exitCode -and $exitCode -ne 0){throw ('Runtime failed '+$exitCode)}
$result=Get-Content -LiteralPath (Join-Path $probeRoot ($Label+'.json')) -Raw | ConvertFrom-Json
if($result.status -ne 'PASS'){throw $result.error}
$stderrPath=Join-Path $probeRoot ($Label+'.stderr.log')
$nativeErrors=@(Get-Content -LiteralPath $stderrPath | Where-Object {$_ -match '\bERROR:'})
@{valid=($nativeErrors.Count -eq 0);nativeErrorCount=$nativeErrors.Count;errors=$nativeErrors;boundary='Any native ERROR invalidates this workload even when Lua status is PASS.'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.validation.json')) -Encoding utf8
if($nativeErrors.Count){throw ('Native logged '+$nativeErrors.Count+' ERROR lines; performance result INVALID. See validation.json.')}
if($result.mode -ne $Mode -or $result.label -ne $Label -or $result.seed -ne 17102026){throw 'Probe identity mismatch.'}
$result.scenarios | Select-Object name,frames,totalMs,perFrameMs,batches,peakBatches,groundCalls | ConvertTo-Json -Depth 5
