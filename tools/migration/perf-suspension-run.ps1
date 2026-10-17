param([string]$RunName='perf-suspension-f94827b2')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$probeRoot=Join-Path $projectRoot ('.tmp/'+$RunName)
$snapshotRoot=Join-Path $probeRoot 'snapshot'
$conflicts=Get-CimInstance Win32_Process -Filter "Name = 'UrhoXRuntime.exe'" -ErrorAction Stop | Where-Object { $_.CommandLine -match '-graphicsheadless' }
if($conflicts){throw 'Another headless measurement is active.'}
if(Test-Path -LiteralPath $snapshotRoot){throw 'Snapshot exists; preserve previous evidence and use a new RunName.'}
New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
$archive=Join-Path $probeRoot 'f94827b2.tar'
git -C $projectRoot archive --format=tar --output=$archive f94827b2 scripts .project
if($LASTEXITCODE -ne 0){throw 'Cannot archive baseline.'}
tar -xf $archive -C $snapshotRoot
if($LASTEXITCODE -ne 0){throw 'Cannot extract baseline.'}
Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts/drive/RaySuspension.lua') -Destination (Join-Path $snapshotRoot 'scripts/drive/RaySuspension.lua')
New-Item -ItemType Junction -Path (Join-Path $snapshotRoot 'assets') -Target (Join-Path $projectRoot 'assets') | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'perf-suspension-native.lua') -Destination (Join-Path $snapshotRoot 'scripts/perf-suspension-native.lua')
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/migration/evidence/perf-suspension-2026-10-16/before/RaySuspension.lua') -Destination (Join-Path $snapshotRoot 'scripts/perf-suspension-baseline.lua')
$runtime='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
$runtimeVersion='0.9.0-beta.40_20261015.121839.6dc5c357cced'
$runIdentity=@{
 baselineCommit=(git -C $projectRoot rev-parse f94827b2)
 runtimePath=$runtime;runtimeVersion=$runtimeVersion;runtimeSha256=(Get-FileHash -LiteralPath $runtime -Algorithm SHA256).Hash
 probeSha256=(Get-FileHash -LiteralPath (Join-Path $snapshotRoot 'scripts/perf-suspension-native.lua') -Algorithm SHA256).Hash
 baselineModuleSha256=(Get-FileHash -LiteralPath (Join-Path $snapshotRoot 'scripts/perf-suspension-baseline.lua') -Algorithm SHA256).Hash
 candidateModuleSha256=(Get-FileHash -LiteralPath (Join-Path $snapshotRoot 'scripts/drive/RaySuspension.lua') -Algorithm SHA256).Hash
 seed=16102026;order=@('baseline-1','candidate-1','candidate-2','baseline-2')
}
$runIdentity | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $probeRoot 'run-identity.json') -Encoding utf8
foreach($label in @('baseline-1','candidate-1','candidate-2','baseline-2')){
 $mode=$label.Split('-')[0]
 $arguments=@('perf-suspension-native.lua',('-tapcode_dir='+$snapshotRoot),'-pp',(Join-Path $projectRoot '.cli/'),'-tool_mode','-skip_login','-skip_isolation','-graphicsheadless','-quality=desktop','-log','info',('-probe-mode='+$mode),('-probe-output='+(Join-Path $probeRoot ($label+'.json'))))
 $probe=Start-Process -FilePath $runtime -ArgumentList $arguments -WorkingDirectory $snapshotRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot ($label+'.stdout.log')) -RedirectStandardError (Join-Path $probeRoot ($label+'.stderr.log'))
 Write-Output ('OWN_RUNTIME_PID='+$probe.Id+' LABEL='+$label)
 if(!$probe.WaitForExit(90000)){$probe.Kill();throw 'Own probe exceeded 90 seconds.'}
 $probe.Refresh()
 $exitCode=$probe.ExitCode
 $exitCodeAvailable=$null -ne $exitCode
 if(!$exitCodeAvailable){Write-Warning ('Native '+$label+' exited after successful WaitForExit, but ExitCode is unavailable; requiring a fresh PASS result and identity checks.')}
 $processEvidence=@{label=$label;mode=$mode;pid=$probe.Id;waitForExitCompleted=$true;exitCodeAvailable=$exitCodeAvailable;exitCode=$exitCode;arguments=$arguments}
 $processEvidence | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $probeRoot ($label+'.process.json')) -Encoding utf8
 if($exitCodeAvailable -and $exitCode -ne 0){throw ('Native exit '+$exitCode)}
 if(!(Test-Path -LiteralPath (Join-Path $probeRoot ($label+'.json')))){throw ('Missing fresh probe output for '+$label)}
 $result=Get-Content -LiteralPath (Join-Path $probeRoot ($label+'.json')) -Raw|ConvertFrom-Json
 if($result.status -ne 'PASS'){throw $result.error}
 if($result.mode -ne $mode -or $result.seed -ne $runIdentity.seed -or $result.runtime -ne $runtimeVersion){throw ('Probe result identity mismatch for '+$label)}
 $result.scenarios|Select-Object name,equivalence,stepTotalMs,sampleMs,applyMs,stateDigest,traceDigest|ConvertTo-Json -Compress
}
