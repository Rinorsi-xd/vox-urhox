param(
 [switch]$ExclusiveCpuWindow,
 [string]$Label='spawn-abba-1',
 [string]$RuntimePath='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
)
$ErrorActionPreference='Stop'
if(!$ExclusiveCpuWindow){throw 'Root must assign an exclusive CPU window before running.'}
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=Join-Path $projectRoot '.tmp/perf-spawn-f1f7d033-b'
if($Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid label'}
$output=Join-Path $probeRoot ($Label+'.json')
if(Test-Path -LiteralPath $output){throw 'Preserve previous evidence: choose another label'}
$identity=Get-Content -LiteralPath (Join-Path $probeRoot 'source-identity.json') -Raw | ConvertFrom-Json
foreach($entry in $identity.sourceHashes.PSObject.Properties){
 if((Get-FileHash -LiteralPath (Join-Path $probeRoot $entry.Name) -Algorithm SHA256).Hash.ToLower() -ne $entry.Value){throw ('Frozen source drift: '+$entry.Name)}
}
$arguments=@('perf-spawn-native.lua',('-tapcode_dir='+$probeRoot),'-pp',(Join-Path $projectRoot '.cli/'),'-tool_mode','-skip_login','-skip_isolation','-graphicsheadless','-log','info',('-probe-output='+$output))
@{runtime=$RuntimePath;runtimeSha256=(Get-FileHash -LiteralPath $RuntimePath -Algorithm SHA256).Hash.ToLower();args=$arguments;probeSha256=(Get-FileHash -LiteralPath (Join-Path $probeRoot 'scripts/perf-spawn-native.lua') -Algorithm SHA256).Hash.ToLower();fixtureSha256=(Get-FileHash -LiteralPath (Join-Path $probeRoot 'spawn-roster.json') -Algorithm SHA256).Hash.ToLower()} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $probeRoot ($Label+'.launch.json')) -Encoding UTF8
$process=Start-Process -FilePath $RuntimePath -ArgumentList $arguments -WorkingDirectory $probeRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($Label+'.stderr.log'))
Write-Output ('OWN_RUNTIME_PID='+$process.Id)
if(!$process.WaitForExit(60000)){$process.Kill();throw 'Own Runtime exceeded 60 seconds'}
if($null -ne $process.ExitCode -and $process.ExitCode -ne 0){throw ('Native exit '+$process.ExitCode)}
$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
if($result.status -ne 'PASS'){throw $result.error}
$result | ConvertTo-Json -Depth 10
