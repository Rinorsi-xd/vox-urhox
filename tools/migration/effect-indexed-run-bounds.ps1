param([switch]$ExclusiveCpuWindow,[Parameter(Mandatory=$true)][string]$Fixture,[Parameter(Mandatory=$true)][string]$Label)
$ErrorActionPreference='Stop'
if(!$ExclusiveCpuWindow){throw 'Root must assign an exclusive CPU window'}
if($Fixture -notmatch '^[A-Za-z0-9_-]+$' -or $Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid fixture or evidence label'}
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=Join-Path $projectRoot ('.tmp/effect-indexed-bounds-'+$Fixture)
$identity=Get-Content -LiteralPath (Join-Path $probeRoot 'identity.json') -Raw | ConvertFrom-Json
function Assert-Hashes($entries,$basePath){foreach($entry in $entries.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $basePath $entry.Name) -Algorithm SHA256).Hash.ToLower() -ne $entry.Value){throw ('Frozen input drift: '+$entry.Name)}}}
Assert-Hashes $identity.hashes $identity.directory
Assert-Hashes $identity.resourceInputs $identity.resources
Assert-Hashes $identity.runtimeInputs $identity.runtimeDirectory
if(@(Get-ChildItem -LiteralPath $probeRoot -File | Where-Object {$_.Name.StartsWith($Label+'.',[StringComparison]::OrdinalIgnoreCase)}).Count){throw 'Preserve prior evidence; choose another label'}
$output=Join-Path $probeRoot ($Label+'.json')
$runtime=Join-Path $identity.runtimeDirectory 'UrhoXRuntime.exe'
$arguments=@('effect-indexed-bounds.lua',('-tapcode_dir='+$probeRoot),'-pp',($identity.resources+'/'),'-tool_mode','-skip_login','-skip_isolation','-quality=desktop','-log','info',('-probe-output='+$output))
@{runtime=$runtime;args=$arguments;sourceHashes=$identity.hashes;runtimeInputs=$identity.runtimeInputs;resourceInputs=$identity.resourceInputs} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.identity.json')) -Encoding UTF8
$process=Start-Process -FilePath $runtime -ArgumentList $arguments -WorkingDirectory $probeRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
$retainedProcessHandle=$process.Handle
Write-Output ('OWN_RUNTIME_PID='+$process.Id)
$completed=$process.WaitForExit(30000)
if(!$completed){$process.Kill();[void]$process.WaitForExit(5000)}
$process.Refresh()
@{pid=$process.Id;completedWithinDeadline=$completed;exitCode=$process.ExitCode;deadlineMs=30000} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.process.json')) -Encoding UTF8
if(!$completed){throw 'Own bounds gate exceeded 30 seconds'}
if($null -ne $process.ExitCode -and $process.ExitCode -ne 0){throw ('Native exit '+$process.ExitCode)}
Assert-Hashes $identity.hashes $identity.directory
Assert-Hashes $identity.resourceInputs $identity.resources
Assert-Hashes $identity.runtimeInputs $identity.runtimeDirectory
$errors=@(Get-Content -LiteralPath (Join-Path $probeRoot ($Label+'.stderr.log')),(Join-Path $probeRoot ($Label+'.stdout.log')) | Where-Object {$_ -match '\bERROR:'})
@{valid=($errors.Count -eq 0);nativeErrors=$errors} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.validation.json')) -Encoding UTF8
if($errors.Count){throw ('INVALID native errors: '+$errors.Count)}
$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
if($result.status -ne 'BOUNDS_PASS'){throw $result.error}
@{status=$result.status;checks=$result.checks;stages=$result.rows.Count;cleanupObjects=$result.cleanup.Count;output=$output} | ConvertTo-Json -Compress
