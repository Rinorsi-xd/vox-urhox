param([switch]$ExclusiveCpuWindow,[Parameter(Mandatory=$true)][string]$Fixture,[Parameter(Mandatory=$true)][string]$Label,
 [ValidateSet('strict','equivalence','timing')][string]$Mode='strict',[ValidateSet('A','B')][string]$Variant='A')
$ErrorActionPreference='Stop'
if(!$ExclusiveCpuWindow){throw 'Root must assign exclusive CPU window'}
if($Fixture -notmatch '^[A-Za-z0-9_-]+$' -or $Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid fixture/label'}
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=Join-Path $projectRoot ('.tmp/effect-indexed-candidate-'+$Fixture)
$identity=Get-Content -LiteralPath (Join-Path $probeRoot 'identity.json') -Raw | ConvertFrom-Json
function Assert-Hashes($entries,$basePath){foreach($entry in $entries.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $basePath $entry.Name) -Algorithm SHA256).Hash.ToLower() -ne $entry.Value){throw ('Frozen input drift: '+$entry.Name)}}}
Assert-Hashes $identity.hashes $identity.directory
Assert-Hashes $identity.resourceInputs $identity.resources
Assert-Hashes $identity.runtimeInputs $identity.runtimeDirectory
if(@(Get-ChildItem -LiteralPath $probeRoot -File | Where-Object {$_.Name.StartsWith($Label+'.',[StringComparison]::OrdinalIgnoreCase)}).Count){throw 'Preserve prior evidence; choose unique label'}
$output=Join-Path $probeRoot ($Label+'.json');$runtime=Join-Path $identity.runtimeDirectory 'UrhoXRuntime.exe'
$entry=if($Mode -eq 'strict'){'effect-indexed-strict.lua'}else{'effect-indexed-mixed.lua'}
$arguments=@($entry,('-tapcode_dir='+$probeRoot),'-pp',($identity.resources+'/'),'-tool_mode','-skip_login','-skip_isolation','-quality=desktop','-log','info',('-probe-output='+$output),('-probe-mode='+$Mode),('-probe-variant='+$Variant),('-probe-label='+$Label))
@{runtime=$runtime;args=$arguments;mode=$Mode;variant=$Variant;sourceHashes=$identity.hashes;runtimeInputs=$identity.runtimeInputs;resourceInputs=$identity.resourceInputs} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.identity.json')) -Encoding UTF8
$process=Start-Process -FilePath $runtime -ArgumentList $arguments -WorkingDirectory $probeRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
$retainedProcessHandle=$process.Handle
Write-Output ('OWN_RUNTIME_PID='+$process.Id)
$completed=$process.WaitForExit(60000)
if(!$completed){$process.Kill();[void]$process.WaitForExit(5000)}
$process.Refresh()
@{pid=$process.Id;completedWithinDeadline=$completed;exitCode=$process.ExitCode;deadlineMs=60000} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.process.json')) -Encoding UTF8
if(!$completed){throw 'Own indexed diagnostic exceeded 60 seconds'}
if($null -ne $process.ExitCode -and $process.ExitCode -ne 0){throw ('Native exit '+$process.ExitCode)}
Assert-Hashes $identity.hashes $identity.directory
Assert-Hashes $identity.resourceInputs $identity.resources
Assert-Hashes $identity.runtimeInputs $identity.runtimeDirectory
$errors=@(Get-Content -LiteralPath (Join-Path $probeRoot ($Label+'.stderr.log')),(Join-Path $probeRoot ($Label+'.stdout.log')) | Where-Object {$_ -match '\bERROR:'})
@{valid=($errors.Count -eq 0);nativeErrors=$errors} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.validation.json')) -Encoding UTF8
if($errors.Count){throw ('INVALID native errors: '+$errors.Count)}
$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
$expected=if($Mode -eq 'strict'){'STRICT_PASS'}else{'PASS'}
if($result.status -ne $expected){throw $result.error}
if($Mode -ne 'strict'){
 $expectedFrames=if($Mode -eq 'equivalence'){180}else{480}
 if($result.mode -ne $Mode -or $result.variant -ne $Variant -or $result.label -ne $Label -or $result.frames -ne $expectedFrames -or $result.warmup -ne 60 -or $result.seed -ne 17102026 -or !$result.collectorRunning){throw 'Incomplete or mismatching mixed identity'}
}
@{status=$result.status;mode=$Mode;variant=$Variant;checks=$result.checks;deindexedVertices=$result.deindexedVertices;frames=$result.frames;totalMs=$result.totalMs;perFrameMs=$result.perFrameMs;output=$output} | ConvertTo-Json -Compress
