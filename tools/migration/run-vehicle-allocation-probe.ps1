param(
 [switch]$ExclusiveCpuWindow,
 [switch]$NormalTiming,
 [string]$ProbeDirectory='.tmp/vehicle-allocation-fd97-a',
 [string]$SupportIdentity='.tmp/perf-damage-flush-adopt-c935-1017/identity.json',
 [string]$Label='allocation-1'
)
$ErrorActionPreference='Stop'
if(!$ExclusiveCpuWindow){throw 'Root must assign an exclusive Native CPU window'}
if($Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid evidence label'}
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=(Resolve-Path -LiteralPath (Join-Path $projectRoot $ProbeDirectory)).Path
$allowedRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp'))+[IO.Path]::DirectorySeparatorChar
if(!$probeRoot.StartsWith($allowedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Derived fixture must stay in workspace .tmp'}
if(@(Get-ChildItem -LiteralPath $probeRoot -File | Where-Object {$_.Name.StartsWith($Label+'.',[StringComparison]::OrdinalIgnoreCase)}).Count){throw 'Preserve all earlier evidence; choose a fresh label'}
$identityPath=Join-Path $probeRoot 'identity.json'
$supportPath=(Resolve-Path -LiteralPath (Join-Path $projectRoot $SupportIdentity)).Path
$identity=Get-Content -LiteralPath $identityPath -Raw -Encoding UTF8 | ConvertFrom-Json
$support=Get-Content -LiteralPath $supportPath -Raw -Encoding UTF8 | ConvertFrom-Json
$timingValidity=if($NormalTiming){'NORMAL_GC_FIXED_WORKLOAD_WALL'}else{'INVALID_FOR_PERFORMANCE'}
if($identity.status -ne 'READY_NOT_RUN' -or $identity.timingValidity -ne $timingValidity){throw 'Matching diagnostic identity required'}
function File-Hash($file){return (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower()}
function Assert-Hashes($entries,$basePath){
 foreach($entry in $entries.PSObject.Properties){
  if((File-Hash (Join-Path $basePath $entry.Name)) -ne $entry.Value){throw ('Frozen input drift: '+$entry.Name)}
 }
}
function Asset-Hashes($assetRoot){
 $base=(Resolve-Path -LiteralPath $assetRoot).Path
 $result=[ordered]@{}
 foreach($file in Get-ChildItem -LiteralPath $base -File -Recurse | Sort-Object FullName){
  $relative=[IO.Path]::GetRelativePath($base,$file.FullName).Replace('\','/')
  $result[$relative]=File-Hash $file.FullName
 }
 return $result
}
Assert-Hashes $identity.sourceHashes $probeRoot
Assert-Hashes $identity.projectHashes $probeRoot
Assert-Hashes $support.resourceInputs $support.resources
Assert-Hashes $support.runtimeInputs $support.runtimeDirectory
if((File-Hash $identity.sourceFrozen) -ne $identity.sourceFrozenSha256){throw 'Frozen source identity changed'}
if($identity.roster){
 if((File-Hash $identity.roster.capturePath) -ne $identity.roster.captureSha256){throw 'Captured roster evidence changed'}
 if((File-Hash $identity.roster.captureReportPath) -ne $identity.roster.captureReportSha256){throw 'Captured runtime report changed'}
}
$assets=Asset-Hashes $identity.assetRoot
$assetsObject=[pscustomobject]$assets
$output=Join-Path $probeRoot ($Label+'.json')
$runtime=Join-Path $support.runtimeDirectory 'UrhoXRuntime.exe'
$entry=if($identity.entry){$identity.entry}elseif($NormalTiming){'vehicle-ray-normal.lua'}else{'vehicle-allocation-probe.lua'}
$arguments=@($entry,('-tapcode_dir='+$probeRoot),'-pp',($support.resources+'/'),'-tool_mode','-skip_login','-skip_isolation','-quality=desktop','-log','info',('-probe-output='+$output))
$launch=@{
 runtime=$runtime;runtimeSha256=$support.runtimeInputs.'UrhoXRuntime.exe';args=$arguments
 identity=$identityPath;identitySha256=(File-Hash $identityPath);supportIdentity=$supportPath;supportIdentitySha256=(File-Hash $supportPath)
 sourceHashes=$identity.sourceHashes;projectHashes=$identity.projectHashes
 resourceInputs=$support.resourceInputs;runtimeInputs=$support.runtimeInputs
 assetRoot=$identity.assetRoot;assetInputs=$assetsObject;timingValidity=$timingValidity
 boundary='Root-owned serial Native fixture. No headless flag; original renderer initialized with no viewport. NormalTiming is normal automatic GC CPU simulation wall timing; allocation mode stops GC for one bounded step and has invalid performance timing. Neither is full-game FPS. Runtime/project/source/assets checked before and after.'
}
$launch | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.launch.json')) -Encoding UTF8
$process=$null;$completed=$false;$exitCode=$null;$processHandle=[IntPtr]::Zero
try{
 $process=Start-Process -FilePath $runtime -ArgumentList $arguments -WorkingDirectory $probeRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
 $processHandle=$process.Handle
 Write-Output ('OWN_RUNTIME_PID='+$process.Id)
 $completed=$process.WaitForExit(60000)
 if(!$completed){$process.Kill();[void]$process.WaitForExit(5000)}
 if($completed){$process.WaitForExit()}
 $process.Refresh();$exitCode=$process.ExitCode
}
finally{
 if($null -ne $process -and !$process.HasExited){$process.Kill();[void]$process.WaitForExit(5000)}
 @{
  pid=if($null -ne $process){$process.Id}else{$null}
  completedWithinDeadline=$completed;exitCode=$exitCode;handleRetained=($processHandle -ne [IntPtr]::Zero)
 } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.process.json')) -Encoding UTF8
}
if(!$completed){throw 'Own diagnostic Runtime exceeded 60 seconds; process evidence preserved'}
if($null -eq $exitCode -or $exitCode -ne 0){throw ('Native exit not confirmed zero: '+$exitCode)}
Assert-Hashes $identity.sourceHashes $probeRoot
Assert-Hashes $identity.projectHashes $probeRoot
Assert-Hashes $support.resourceInputs $support.resources
Assert-Hashes $support.runtimeInputs $support.runtimeDirectory
Assert-Hashes $assetsObject $identity.assetRoot
$errors=@(Get-Content -LiteralPath (Join-Path $probeRoot ($Label+'.stderr.log')),(Join-Path $probeRoot ($Label+'.stdout.log')) -Encoding UTF8 | Where-Object {$_ -match '\bERROR:'} | ForEach-Object {[string]::Concat('',$_)})
@{valid=($errors.Count -eq 0);nativeErrors=$errors;timingValidity=$timingValidity} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.validation.json')) -Encoding UTF8
if($errors.Count){throw ('INVALID native errors: '+$errors.Count)}
$result=Get-Content -LiteralPath $output -Raw -Encoding UTF8 | ConvertFrom-Json
if($NormalTiming){
 if($result.status -ne 'NORMAL_GC_TIMING_PASS' -or !$result.collectorGuardRestored -or !$result.collectorRunning -or $result.frames.Count -ne $identity.configuration.steps){throw ('Normal timing incomplete; inspect '+$output)}
 @{status=$result.status;output=$output;steps=$result.frames.Count;meanStepMs=$result.meanStepMs;maxStepMs=$result.maxStepMs;profile=$identity.configuration.profile;runtimeExitCode=$exitCode;nativeErrors=$errors.Count;timingValidity=$timingValidity} | ConvertTo-Json -Compress
 return
}
if($result.status -ne 'ALLOCATION_DIAGNOSTIC_PASS' -or !$result.collectorGuardRestored -or !$result.allocation.restored -or $result.allocation.aborted -or $result.allocation.frames.Count -ne $identity.configuration.samples){throw ('Diagnostic incomplete; inspect preserved result '+$output)}
@{status=$result.status;output=$output;samples=$result.allocation.frames.Count;measuredShots=$result.measuredShots;collectorRestored=$result.allocation.restored;runtimeExitCode=$exitCode;nativeErrors=$errors.Count;timingValidity='INVALID_FOR_PERFORMANCE'} | ConvertTo-Json -Compress
