param(
 [switch]$ExclusiveCpuWindow,
 [ValidateSet('A','B')][string]$Variant='A',
 [ValidateSet('profile','timing','equivalence')][string]$Mode='profile',
 [ValidateSet('arcs','bolts','mixed')][string]$Scenario='mixed',
 [string]$Label='profile-A-mixed-v2-1'
)
$ErrorActionPreference='Stop'
if(!$ExclusiveCpuWindow){throw 'Root must assign an exclusive CPU window'}
if($Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid evidence label'}
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=Join-Path $projectRoot '.tmp/perf-effects-zap-native-1017-v2'
if(@(Get-ChildItem -LiteralPath $probeRoot -File | Where-Object {$_.Name.StartsWith($Label+'.',[StringComparison]::OrdinalIgnoreCase)}).Count){throw 'Preserve every prior result/log/identity; choose another label'}
$identity=Get-Content -LiteralPath (Join-Path $probeRoot 'identity.json') -Raw | ConvertFrom-Json
$snapshot=$identity.snapshots.$Variant
$output=Join-Path $probeRoot ($Label+'.json')
function Assert-Hashes($entries,$basePath){
 foreach($entry in $entries.PSObject.Properties){
  if((Get-FileHash -LiteralPath (Join-Path $basePath $entry.Name) -Algorithm SHA256).Hash.ToLower() -ne $entry.Value){throw ('Frozen input drift: '+$entry.Name)}
 }
}
Assert-Hashes $snapshot.hashes $snapshot.snapshot
Assert-Hashes $identity.resourceInputs $identity.resources
Assert-Hashes $identity.runtimeInputs $identity.runtimeDirectory
$runtime=Join-Path $identity.runtimeDirectory 'UrhoXRuntime.exe'
$arguments=@('perf-effects-zap-native.lua',('-tapcode_dir='+$snapshot.snapshot),'-pp',($identity.resources+'/'),'-tool_mode','-skip_login','-skip_isolation','-quality=desktop','-log','info',('-probe-mode='+$Mode),('-probe-label='+$Label),('-probe-scenario='+$Scenario),('-probe-output='+$output))
@{variant=$Variant;mode=$Mode;scenario=$Scenario;label=$Label;runtime=$runtime;runtimeSha256=$identity.runtimeInputs.'UrhoXRuntime.exe';runtimeInputs=$identity.runtimeInputs;resourcePrefix=$identity.resources;resourceInputs=$identity.resourceInputs;args=$arguments;sourceManifest=$identity.sourceManifest;sourceHashes=$snapshot.hashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.identity.json')) -Encoding UTF8
$process=Start-Process -FilePath $runtime -ArgumentList $arguments -WorkingDirectory $snapshot.snapshot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
Write-Output ('OWN_RUNTIME_PID='+$process.Id)
$completed=$process.WaitForExit(60000)
if(!$completed){$process.Kill();[void]$process.WaitForExit(5000)}
@{pid=$process.Id;completedWithinDeadline=$completed;exitCode=$process.ExitCode;deadlineMs=60000} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.process.json')) -Encoding UTF8
if(!$completed){throw 'Own Native effects diagnostic exceeded 60 seconds'}
if($null -ne $process.ExitCode -and $process.ExitCode -ne 0){throw ('Native exit '+$process.ExitCode)}
Assert-Hashes $snapshot.hashes $snapshot.snapshot
Assert-Hashes $identity.resourceInputs $identity.resources
Assert-Hashes $identity.runtimeInputs $identity.runtimeDirectory
$errors=@(Get-Content -LiteralPath (Join-Path $probeRoot ($Label+'.stderr.log')),(Join-Path $probeRoot ($Label+'.stdout.log')) | Where-Object {$_ -match '\bERROR:'})
@{valid=($errors.Count -eq 0);nativeErrors=$errors} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.validation.json')) -Encoding UTF8
if($errors.Count){throw ('INVALID native errors: '+$errors.Count+'; no performance claim')}
$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
if($result.status -ne 'PASS'){throw $result.error}
if($result.mode -ne $Mode -or $result.label -ne $Label -or $result.seed -ne 17102026 -or $result.scenarios.Count -ne 1 -or $result.scenarios[0].name -ne $Scenario){throw 'Probe identity mismatch'}
$expectedFrames=if($Mode -eq 'equivalence'){180}else{480}
if($result.scenarios[0].frames -ne $expectedFrames -or !$result.scenarios[0].collectorRunning){throw 'Incomplete frames or collector stopped'}
$result | ConvertTo-Json -Depth 8
