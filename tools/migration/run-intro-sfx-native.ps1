param([string]$Fixture='.tmp/intro-sfx-native-20261017',[string]$Label='native-1')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixtureRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot $Fixture))
$allowed=[IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp'))+[IO.Path]::DirectorySeparatorChar
if(!$fixtureRoot.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Fixture must remain under workspace .tmp.'}
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Label must be a simple evidence name.'}
$identity=Get-Content -LiteralPath (Join-Path $fixtureRoot 'identity.json') -Raw | ConvertFrom-Json
foreach($file in $identity.sourceHashes.PSObject.Properties){
 if((Get-FileHash -LiteralPath (Join-Path $fixtureRoot $file.Name) -Algorithm SHA256).Hash.ToLower() -ne $file.Value){throw ('Frozen fixture drift: '+$file.Name)}
}
if((Get-FileHash -LiteralPath (Join-Path $fixtureRoot 'scripts/intro-sfx-native.lua') -Algorithm SHA256).Hash.ToLower() -ne $identity.probeSha256){throw 'Probe drift.'}
$runtimeRoot=[string]$identity.runtimeRoot
if(!$runtimeRoot -or !([IO.Path]::GetFullPath($runtimeRoot)).StartsWith($fixtureRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Prepare a new fixture with an isolated Runtime inside its root.'}
$runtime=Join-Path $runtimeRoot 'UrhoXRuntime.exe'
if(!(Test-Path -LiteralPath $runtime)){throw 'Existing isolated beta40 runtime is unavailable; do not substitute a different engine silently.'}
$expectedRuntime='f6a2ae8893bebb66b0dce1f6687a6ba0cd98454a20069541b5557cbf5f79772c'
$actualRuntime=(Get-FileHash -LiteralPath $runtime -Algorithm SHA256).Hash.ToLower()
if($actualRuntime -ne $expectedRuntime){throw 'Existing Native Runtime identity differs.'}
if(!$identity.runtimeFiles -or !$identity.bootstrapResources -or !$identity.resourceJunctions){throw 'Prepare a new fixture with explicit executable-adjacent resource identity.'}
foreach($entry in @($identity.runtimeFiles.PSObject.Properties)+@($identity.bootstrapResources.PSObject.Properties)){
 if((Get-FileHash -LiteralPath (Join-Path $runtimeRoot $entry.Name) -Algorithm SHA256).Hash.ToLower() -ne $entry.Value){throw ('Native resource identity drift: '+$entry.Name)}
}
foreach($junction in $identity.resourceJunctions.PSObject.Properties){
 $actualTarget=(Get-Item -LiteralPath $junction.Name).Target
 if([IO.Path]::GetFullPath([string]$actualTarget) -ne [IO.Path]::GetFullPath([string]$junction.Value)){throw ('Core resource junction drift: '+$junction.Name)}
}
$output=Join-Path $fixtureRoot ($Label+'.json')
if(Test-Path -LiteralPath $output){throw 'Output exists; choose another label.'}
$arguments=@('intro-sfx-native.lua',('-tapcode_dir='+$fixtureRoot),'-tool_mode','-skip_login','-skip_isolation','-quality=desktop','-log','info',('-probe-output='+$output))
$owned=Start-Process -FilePath $runtime -ArgumentList $arguments -WorkingDirectory $fixtureRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $fixtureRoot ($Label+'.stdout.log')) -RedirectStandardError (Join-Path $fixtureRoot ($Label+'.stderr.log'))
Write-Output ('OWN_AUDIO_RUNTIME_PID='+$owned.Id)
if(!$owned.WaitForExit(30000)){
 $owned.Kill();$owned.WaitForExit()
 @{status='TIMEOUT';pid=$owned.Id;runtime=$runtime;runtimeSha256=$actualRuntime;deadlineMs=30000} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fixtureRoot ($Label+'.process.json')) -Encoding utf8
 throw 'Only this owned fixture process exceeded the 30-second deadline and was stopped.'
}
$owned.Refresh()
@{status='CLOSED';pid=$owned.Id;exitCode=$owned.ExitCode;runtime=$runtime;runtimeSha256=$actualRuntime;arguments=$arguments} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $fixtureRoot ($Label+'.process.json')) -Encoding utf8
if(!(Test-Path -LiteralPath $output)){throw 'Native fixture did not produce a result; inspect its stdout/stderr.'}
$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
$errors=@(Get-Content -LiteralPath (Join-Path $fixtureRoot ($Label+'.stderr.log')) | Where-Object {$_ -match '\bERROR:'})
if($result.status -ne 'PASS' -or $errors.Count){throw ('Fixture not accepted: '+$result.error+'; native ERROR count='+$errors.Count)}
$result | ConvertTo-Json -Depth 8
