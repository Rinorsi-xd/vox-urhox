param(
 [switch]$ExclusiveCpuWindow,
 [ValidateSet('A','B')][string]$Variant='A',
 [ValidateSet('profile','timing','equivalence')][string]$Mode='profile',
 [ValidateSet('arcs','bolts','mixed')][string]$Scenario='mixed',
 [string]$Label='profile-A-mixed-1',
 [string]$RuntimePath='.tmp/perf-effects-runtime-beta40/UrhoXRuntime.exe',
 [string]$ResourcePrefix='.cli'
)
$ErrorActionPreference='Stop'
if(!$ExclusiveCpuWindow){throw 'Root must assign an exclusive CPU window'}
if($Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid evidence label'}
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=Join-Path $projectRoot '.tmp/perf-effects-zap-native-1017'
$identity=Get-Content -LiteralPath (Join-Path $probeRoot 'identity.json') -Raw | ConvertFrom-Json
$snapshot=$identity.snapshots.$Variant
$output=Join-Path $probeRoot ($Label+'.json')
if(Test-Path -LiteralPath $output){throw 'Preserve existing evidence; choose another label'}
foreach($entry in $snapshot.hashes.PSObject.Properties){
 if((Get-FileHash -LiteralPath (Join-Path $snapshot.snapshot $entry.Name) -Algorithm SHA256).Hash.ToLower() -ne $entry.Value){throw ('Frozen source drift: '+$entry.Name)}
}
$runtime=(Resolve-Path -LiteralPath (Join-Path $projectRoot $RuntimePath)).Path
$resources=(Resolve-Path -LiteralPath (Join-Path $projectRoot $ResourcePrefix)).Path
$arguments=@('perf-effects-zap-native.lua',('-tapcode_dir='+$snapshot.snapshot),'-pp',($resources+'/'),'-tool_mode','-skip_login','-skip_isolation','-quality=desktop','-log','info',('-probe-mode='+$Mode),('-probe-label='+$Label),('-probe-scenario='+$Scenario),('-probe-output='+$output))
@{variant=$Variant;mode=$Mode;scenario=$Scenario;label=$Label;runtime=$runtime;runtimeSha256=(Get-FileHash -LiteralPath $runtime -Algorithm SHA256).Hash.ToLower();resourcePrefix=$resources;args=$arguments;sourceManifest=$identity.sourceManifest;sourceHashes=$snapshot.hashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.identity.json')) -Encoding UTF8
$process=Start-Process -FilePath $runtime -ArgumentList $arguments -WorkingDirectory $snapshot.snapshot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
Write-Output ('OWN_RUNTIME_PID='+$process.Id)
if(!$process.WaitForExit(60000)){$process.Kill();throw 'Own Native effects diagnostic exceeded 60 seconds'}
if($null -ne $process.ExitCode -and $process.ExitCode -ne 0){throw ('Native exit '+$process.ExitCode)}
$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
if($result.status -ne 'PASS'){throw $result.error}
$errors=@(Get-Content -LiteralPath (Join-Path $probeRoot ($Label+'.stderr.log')),(Join-Path $probeRoot ($Label+'.stdout.log')) | Where-Object {$_ -match '\bERROR:'})
@{valid=($errors.Count -eq 0);nativeErrors=$errors} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.validation.json')) -Encoding UTF8
if($errors.Count){throw ('INVALID native errors: '+$errors.Count+'; no performance claim')}
if($result.mode -ne $Mode -or $result.label -ne $Label -or $result.seed -ne 17102026 -or $result.scenarios[0].name -ne $Scenario){throw 'Probe identity mismatch'}
if(!$result.scenarios[0].collectorRunning){throw 'Normal collector stopped'}
$result | ConvertTo-Json -Depth 8
