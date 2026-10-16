param([switch]$ExclusiveNativeWindow)
$ErrorActionPreference='Stop'
if(-not $ExclusiveNativeWindow){throw 'Root must allocate the exclusive native window.'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$baseline=Join-Path $projectRoot '.tmp/outgame-cached-1792105799832'
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/body-point-native-'+$stamp)
New-Item -ItemType Directory -Path $evidence | Out-Null
$files=@('scripts/physics/Body.lua','scripts/core/Coord.lua','tools/migration/check-body-point-native.lua',
    'tools/migration/verify-body-point-native.ps1','.tmp/outgame-cached-1792105799832/scripts/physics/Body.lua')
function ProbeHashes {
    $hashes=[ordered]@{}
    foreach($file in $files){$hashes[$file]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $file) -Algorithm SHA256).Hash}
    return $hashes
}
$manifest=[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');before=ProbeHashes;
    baselineManifest='989c7ba6';scope='Actual native RigidBody/Box point velocity only; not application or performance acceptance';
    existingRuntimePids=@(Get-Process -Name UrhoXRuntime -ErrorAction SilentlyContinue|ForEach-Object {$_.Id})}
$result=Join-Path $evidence 'validator.json'
$measurements=Join-Path $evidence 'point-velocity.json'
$runtimeArgs=@('_body_point_native_check.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
    '-validate-frames=10','-validate-timeout=45','-validate-spike-threshold=30000',
    ('-validate-output='+$result),'-log','info',('-validate-test='+$PSScriptRoot+'/check-body-point-native.lua'),
    ('-body-before='+$baseline),('-body-output='+$measurements))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($evidence+'/stdout.txt') -RedirectStandardError ($evidence+'/stderr.txt')
$manifest.probePid=$process.Id
$deadline=[DateTime]::UtcNow.AddSeconds(60)
$timedOut=$false
while(-not $process.WaitForExit(500)){
    if([DateTime]::UtcNow -ge $deadline){$timedOut=$true;$process.Kill();$process.WaitForExit();break}
}
$manifest.after=ProbeHashes
$manifest.finishedUtc=[DateTime]::UtcNow.ToString('o');$manifest.runtimeExit=$process.ExitCode;$manifest.timedOut=$timedOut
$manifest.changedDuringRun=@($files|Where-Object {$manifest.before[$_] -ne $manifest.after[$_]})
$manifest.existingRuntimePidsAfter=@(Get-Process -Name UrhoXRuntime -ErrorAction SilentlyContinue|ForEach-Object {$_.Id})
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'manifest.json') -Encoding utf8
Write-Output $evidence
if($timedOut){throw 'Only the probe process was terminated at the 60 second deadline.'}
if($manifest.changedDuringRun.Count){throw 'Probe inputs changed during native run.'}
if(-not(Test-Path -LiteralPath $result) -or -not(Test-Path -LiteralPath $measurements)){throw 'Native probe did not emit complete reports.'}
$native=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json
$point=Get-Content -LiteralPath $measurements -Raw|ConvertFrom-Json
$native|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
$point|Select-Object result,complete,assertions,failures,error|ConvertTo-Json -Depth 5
if($point.result -ne 'PASSED' -or -not $point.complete -or $native.test_result -ne 'PASSED' -or $native.result -ne 'PASS'){throw 'Native point comparison failed.'}
