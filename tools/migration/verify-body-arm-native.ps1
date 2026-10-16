param([switch]$ExclusiveNativeWindow)
$ErrorActionPreference='Stop'
if(-not $ExclusiveNativeWindow){throw 'Root must allocate the exclusive native window.'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$baseline=Join-Path $projectRoot '.tmp/outgame-cached-1792108710605'
$entry=Join-Path $projectRoot 'scripts/_body_arm_native_check.lua'
if((Test-Path -LiteralPath $entry) -or (Test-Path -LiteralPath ($entry+'.meta'))){throw 'Arm fixture temporary entry already exists.'}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/body-arm-native-'+$stamp)
New-Item -ItemType Directory -Path $evidence | Out-Null
$files=@('scripts/physics/Body.lua','scripts/core/Coord.lua','scripts/physics/Space.lua','scripts/drive/RaySuspension.lua',
    'tools/migration/check-body-arm-native.lua','tools/migration/verify-body-arm-native.ps1','tools/migration/entries/body-arm.lua',
    '.tmp/outgame-cached-1792108710605/scripts/physics/Body.lua',
    '.tmp/outgame-cached-1792108710605/scripts/drive/RaySuspension.lua',
    '.tmp/outgame-cached-1792108710605/scripts/physics/Space.lua')
function ProbeHashes {
    $hashes=[ordered]@{}
    foreach($file in $files){$hashes[$file]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $file) -Algorithm SHA256).Hash}
    return $hashes
}
$manifest=[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');before=ProbeHashes;baselineManifest='d01102e0';
    scope='Windows native exact-state comparison and paired complete-suspension CPU fixture';
    existingRuntimePids=@(Get-Process -Name UrhoXRuntime -ErrorAction SilentlyContinue|ForEach-Object {$_.Id})}
$result=Join-Path $evidence 'validator.json'
$measurements=Join-Path $evidence 'body-arm.json'
$runtimeArgs=@('_body_arm_native_check.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
    '-validate-frames=10','-validate-timeout=60','-validate-spike-threshold=60000',
    ('-validate-output='+$result),'-log','info',('-validate-test='+$PSScriptRoot+'/check-body-arm-native.lua'),
    ('-body-before='+$baseline),('-body-output='+$measurements))
$timedOut=$false
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'entries/body-arm.lua') -Destination $entry
try {
    $process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($evidence+'/stdout.txt') -RedirectStandardError ($evidence+'/stderr.txt')
    $manifest.probePid=$process.Id
    $deadline=[DateTime]::UtcNow.AddSeconds(75)
    while(-not $process.WaitForExit(500)){
        if([DateTime]::UtcNow -ge $deadline){$timedOut=$true;$process.Kill();$process.WaitForExit();break}
    }
} finally {
    Remove-Item -LiteralPath $entry
    if(Test-Path -LiteralPath ($entry+'.meta')){Remove-Item -LiteralPath ($entry+'.meta')}
}
$manifest.after=ProbeHashes
$manifest.finishedUtc=[DateTime]::UtcNow.ToString('o');$manifest.runtimeExit=$process.ExitCode;$manifest.timedOut=$timedOut
$manifest.changedDuringRun=@($files|Where-Object {$manifest.before[$_] -ne $manifest.after[$_]})
$manifest.existingRuntimePidsAfter=@(Get-Process -Name UrhoXRuntime -ErrorAction SilentlyContinue|ForEach-Object {$_.Id})
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'manifest.json') -Encoding utf8
Write-Output $evidence
if($timedOut){throw 'Only the probe process was terminated at the 75 second deadline.'}
if($manifest.changedDuringRun.Count){throw 'Probe inputs changed during native run.'}
if(-not(Test-Path -LiteralPath $result) -or -not(Test-Path -LiteralPath $measurements)){throw 'Native probe did not emit complete reports.'}
$native=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json
$point=Get-Content -LiteralPath $measurements -Raw|ConvertFrom-Json
$native|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
$point|Select-Object result,complete,assertions,failures,error|ConvertTo-Json -Depth 5
$point|Select-Object controlMedianRatio,rayMedianRatio,rayWins,timingAccepted|ConvertTo-Json
$point.rayControls|ForEach-Object {[pscustomobject]@{pass=$_.pass;firstMs=$_.first.cpuMs;secondMs=$_.second.cpuMs;ratio=$_.ratio}}|ConvertTo-Json
$point.rayTimings|ForEach-Object {[pscustomobject]@{pass=$_.pass;beforeMs=$_.before.cpuMs;currentMs=$_.current.cpuMs;ratio=$_.ratio}}|ConvertTo-Json
if($point.result -ne 'PASSED' -or -not $point.complete -or $native.test_result -ne 'PASSED' -or $native.result -ne 'PASS'){throw 'Native arm comparison failed.'}
