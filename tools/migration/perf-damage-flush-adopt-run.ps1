param([switch]$ExclusiveCpuWindow,[ValidateSet('A','B')][string]$Variant='A',[string]$Label='adopt-A1')
$ErrorActionPreference='Stop'
if(!$ExclusiveCpuWindow){throw 'Root must assign an exclusive CPU window'}
if($Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid label'}
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=Join-Path $projectRoot '.tmp/perf-damage-flush-adopt-c935-1017'
if(@(Get-ChildItem -LiteralPath $probeRoot -File | Where-Object {$_.Name.StartsWith($Label+'.',[StringComparison]::OrdinalIgnoreCase)}).Count){throw 'Preserve all prior evidence; choose another label'}
$identity=Get-Content -LiteralPath (Join-Path $probeRoot 'identity.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$snapshot=$identity.variants.$Variant
function Assert-Hashes($entries,$basePath){foreach($entry in $entries.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $basePath $entry.Name) -Algorithm SHA256).Hash.ToLower() -ne $entry.Value){throw ('Frozen input drift: '+$entry.Name)}}}
Assert-Hashes $snapshot.hashes $snapshot.directory
Assert-Hashes $identity.resourceInputs $identity.resources
Assert-Hashes $identity.runtimeInputs $identity.runtimeDirectory
$output=Join-Path $probeRoot ($Label+'.json')
$runtime=Join-Path $identity.runtimeDirectory 'UrhoXRuntime.exe'
$arguments=@('perf-damage-flush-adopt-native.lua',('-tapcode_dir='+$snapshot.directory),'-pp',($identity.resources+'/'),'-tool_mode','-skip_login','-skip_isolation','-quality=desktop','-log','info',('-probe-output='+$output))
@{variant=$Variant;runtime=$runtime;runtimeSha256=$identity.runtimeInputs.'UrhoXRuntime.exe';args=$arguments;fixture=$identity.fixture;sourceHashes=$snapshot.hashes;resourceInputs=$identity.resourceInputs;boundary=$identity.boundary} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.launch.json')) -Encoding UTF8
$process=Start-Process -FilePath $runtime -ArgumentList $arguments -WorkingDirectory $snapshot.directory -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
$processHandle=$process.Handle
Write-Output ('OWN_RUNTIME_PID='+$process.Id)
$completed=$process.WaitForExit(60000)
if(!$completed){$process.Kill();[void]$process.WaitForExit(5000)}
if($completed){$process.WaitForExit()}
$process.Refresh();$exitCode=$process.ExitCode
@{pid=$process.Id;completedWithinDeadline=$completed;exitCode=$exitCode;handleRetained=($processHandle -ne [IntPtr]::Zero)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.process.json')) -Encoding UTF8
if(!$completed){throw 'Own Runtime exceeded 60 seconds'}
if($null -eq $exitCode -or $exitCode -ne 0){throw ('Native exit not confirmed zero: '+$exitCode)}
Assert-Hashes $snapshot.hashes $snapshot.directory
Assert-Hashes $identity.resourceInputs $identity.resources
Assert-Hashes $identity.runtimeInputs $identity.runtimeDirectory
$errors=@(Get-Content -LiteralPath (Join-Path $probeRoot ($Label+'.stderr.log')),(Join-Path $probeRoot ($Label+'.stdout.log')) -Encoding UTF8 | Where-Object {$_ -match '\bERROR:'} | ForEach-Object {[string]::Concat('',$_)})
@{valid=($errors.Count -eq 0);nativeErrors=$errors} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.validation.json')) -Encoding UTF8
if($errors.Count){throw ('INVALID native errors: '+$errors.Count)}
$result=Get-Content -LiteralPath $output -Raw -Encoding UTF8 | ConvertFrom-Json
if($result.status -ne 'PASS' -or !$result.cleanup -or !$result.collectorRunning -or $result.steps.Count -ne $identity.expectedSteps -or $result.batches -ne $identity.expectedBatches -or $result.loading.Count -ne $identity.expectedLoadingRows){throw 'Native probe incomplete; preserve raw data'}
@{status=$result.status;variant=$Variant;output=$output;steps=$result.steps.Count;batches=$result.batches;flushWallMs=($result.steps | ForEach-Object {$_.flush.wallMs} | Measure-Object -Sum).Sum;turretWallMs=($result.steps | ForEach-Object {$_.stats.'turretRange.For'.wallMs} | Measure-Object -Sum).Sum;boundary=$identity.boundary} | ConvertTo-Json -Compress
