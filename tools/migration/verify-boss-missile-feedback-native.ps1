param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Label,
    [string]$Snapshot='.tmp/outgame-cached-1792213080660',
    [switch]$Run
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$snapshotRoot=(Resolve-Path -LiteralPath (Join-Path $projectRoot $Snapshot)).Path
$allowedRoot=Join-Path $projectRoot '.tmp'
if(-not $snapshotRoot.StartsWith($allowedRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Snapshot must be an isolated workspace .tmp directory'}
$outputRoot=Join-Path $allowedRoot ('g4-boss-missile-native-'+$Label)
if(Test-Path -LiteralPath $outputRoot){throw 'Output already exists; preserve prior evidence and choose a new label'}
$snapshotIdentity=Get-Content -LiteralPath (Join-Path $snapshotRoot 'identity.json') -Raw | ConvertFrom-Json
if(-not $snapshotIdentity.ok){throw 'Snapshot identity is not valid'}
$sourceHashes=$snapshotIdentity.identity.scripts
$luaFiles=@(Get-ChildItem -LiteralPath (Join-Path $snapshotRoot 'scripts') -Recurse -File -Filter '*.lua')
if($luaFiles.Count -ne @($sourceHashes.PSObject.Properties).Count){throw 'Frozen Lua file count differs from identity'}
foreach($entry in $sourceHashes.PSObject.Properties){
    $file=Join-Path (Join-Path $snapshotRoot 'scripts') $entry.Name
    if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value){throw ('Frozen Lua identity mismatch: '+$entry.Name)}
}
if($sourceHashes.'combat/StoryBoss.lua' -ne '25e4a402d6a8bf7dc577553437ca17cecc27ce5d47d272aad54564166ba5102a'){throw 'Snapshot does not contain the reviewed Boss feedback candidate'}
$supportRoot=Join-Path $allowedRoot 'perf-effects-zap-native-1017-v2'
$support=Get-Content -LiteralPath (Join-Path $supportRoot 'identity.json') -Raw | ConvertFrom-Json
function Assert-Hashes($values,[string]$basePath){
    foreach($entry in $values.PSObject.Properties){
        if((Get-FileHash -LiteralPath (Join-Path $basePath $entry.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value){throw ('Native support drift: '+$entry.Name)}
    }
}
Assert-Hashes $support.runtimeInputs $support.runtimeDirectory
Assert-Hashes $support.resourceInputs $support.resources
$runtime=Join-Path $support.runtimeDirectory 'UrhoXRuntime.exe'
$validator=Join-Path $PSScriptRoot 'check-boss-missile-feedback-native.lua'
$validatorHash=(Get-FileHash -LiteralPath $validator -Algorithm SHA256).Hash.ToLowerInvariant()
$report=Join-Path $outputRoot 'validation.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$snapshotRoot),'-pp',($support.resources+[IO.Path]::DirectorySeparatorChar),
    '-tool_mode','-skip_login','-skip_isolation','-quality=desktop','-validate','-validate-frames=1410',
    '-validate-timeout=180','-validate-spike-threshold=20000',('-validate-output='+$report),
    ('-validate-test='+$validator),'-log','info')
New-Item -ItemType Directory -Path $outputRoot | Out-Null
$launch=@{status='PREFLIGHT_ONLY';snapshot=$snapshotRoot;sourceCommit=$snapshotIdentity.identity.sourceCommit;
    targetCommit=$snapshotIdentity.identity.targetCommit;sourceHashes=$sourceHashes;runtime=$runtime;
    runtimeInputs=$support.runtimeInputs;resources=$support.resources;resourceInputs=$support.resourceInputs;
    validator=$validator;validatorSha256=$validatorHash;arguments=$runtimeArgs;workingDirectory=$projectRoot;
    boundary='Controlled real S5 loading, Boss projectile impact and normal return only. No natural S5 completion, audible cue, subjective shake, Web, performance or mobile acceptance.'}
if($Run){$launch.status='LAUNCH_REQUESTED'}
$launch | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputRoot 'launch.json') -Encoding UTF8
if(-not $Run){
    Write-Output ('PREFLIGHT_ONLY: '+$outputRoot)
    Write-Output ('Verified '+$luaFiles.Count+' frozen Lua files and matching Native dependencies; no process started.')
    return
}
$process=Start-Process -FilePath $runtime -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput (Join-Path $outputRoot 'stdout.log') -RedirectStandardError (Join-Path $outputRoot 'stderr.log')
@{pid=$process.Id;startedAt=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'process.json') -Encoding UTF8
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $process.WaitForExit(1000)){
    if($timer.Elapsed.TotalSeconds -gt 195){
        $process.Kill()
        $process.WaitForExit()
        @{status='TIMEOUT';pid=$process.Id;exitCode=$process.ExitCode} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'completion.json') -Encoding UTF8
        throw 'Owned Boss missile validation exceeded the 195-second external deadline'
    }
}
@{status='EXITED';pid=$process.Id;exitCode=$process.ExitCode;elapsedSeconds=$timer.Elapsed.TotalSeconds} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'completion.json') -Encoding UTF8
Assert-Hashes $support.runtimeInputs $support.runtimeDirectory
Assert-Hashes $support.resourceInputs $support.resources
if((Get-FileHash -LiteralPath $validator -Algorithm SHA256).Hash.ToLowerInvariant() -ne $validatorHash){throw 'Validator changed during actual run'}
if($process.ExitCode -ne 0){throw ('Native Runtime exited '+$process.ExitCode)}
if(-not(Test-Path -LiteralPath $report)){throw 'Boss missile validation report missing; retain stdout/stderr'}
$result=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$result | Select-Object result,test_result,test_assertions,summary,test_issues,missing_resources | ConvertTo-Json -Depth 8
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Boss missile validation failed; preserve all evidence'}
