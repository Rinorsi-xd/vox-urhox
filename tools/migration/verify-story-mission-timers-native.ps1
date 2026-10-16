param([switch]$ExclusiveNativeWindow,[switch]$SelfTest)
$ErrorActionPreference='Stop'
function Wait-MissionTimersProcess($Process,[int]$TimeoutSeconds) {
    $null=$Process.Handle
    $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds);$timedOut=$false
    while(-not $Process.WaitForExit(500)){
        if([DateTime]::UtcNow -ge $deadline){$timedOut=$true;$Process.Kill();break}
    }
    $Process.WaitForExit();$exitCode=$Process.ExitCode
    if($null -eq $exitCode){throw 'Child exited without a readable status.'}
    return @{exitCode=$exitCode;timedOut=$timedOut}
}
function Assert-MissionTimersEvidence($Native,[string]$Log) {
    if($Native.result -ne 'PASS' -or $Native.test_result -ne 'PASSED' -or
       $null -eq $Native.summary.total_errors -or $Native.summary.total_errors -ne 0 -or
       $Native.test_assertions.total -ne 20 -or $Native.test_assertions.passed -ne 20 -or
       $null -eq $Native.test_assertions.failed -or $Native.test_assertions.failed -ne 0 -or
       -not $Log.Contains('[MissionTimersNative] started') -or
       -not $Log.Contains('[MissionTimersNative] completed 20 checks;')) {
        throw 'Mission timers require exactly 20 passed assertions, zero errors and both execution markers.'
    }
}
if($SelfTest){
    $valid='{"result":"PASS","test_result":"PASSED","summary":{"total_errors":0},"test_assertions":{"total":20,"passed":20,"failed":0}}'
    $log='[MissionTimersNative] started [MissionTimersNative] completed 20 checks;'
    Assert-MissionTimersEvidence ($valid|ConvertFrom-Json) $log
    $cases=@(
        @{json=$valid.Replace('20','0');log=$log},
        @{json=$valid.Replace('"passed":20','"passed":19');log=$log},
        @{json=$valid.Replace('"failed":0','"failed":1');log=$log},
        @{json=$valid.Replace('"total_errors":0','"total_errors":1');log=$log},
        @{json=$valid.Replace('"result":"PASS"','"result":"FAIL"');log=$log},
        @{json=$valid;log='[MissionTimersNative] started'},
        @{json=$valid;log='[MissionTimersNative] completed 20 checks;'}
    )
    foreach($case in $cases){
        $rejected=$false
        try {Assert-MissionTimersEvidence ($case.json|ConvertFrom-Json) $case.log} catch {$rejected=$true}
        if(-not $rejected){throw 'Evidence gate accepted an incomplete fixture.'}
    }
    foreach($expectedExit in @(0,7)){
        $child=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile','-Command',('Start-Sleep -Milliseconds 150; exit '+$expectedExit))
        $state=Wait-MissionTimersProcess $child 10
        if($state.timedOut -or $state.exitCode -ne $expectedExit){throw 'Process exit control failed.'}
    }
    Write-Output 'Mission timers gate: 1 positive, 7 negative and 2 real process controls PASS; no native runtime launched.'
    return
}
if(-not $ExclusiveNativeWindow){throw 'Root must allocate the exclusive native window.'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$entry=Join-Path $projectRoot 'scripts/_mission_timers_native_check.lua'
if((Test-Path -LiteralPath $entry) -or (Test-Path -LiteralPath ($entry+'.meta'))){throw 'Temporary mission timers entry exists.'}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/story-mission-timers-native-'+$stamp)
New-Item -ItemType Directory -Path $evidence | Out-Null
$files=@('scripts/story/Mission.lua','scripts/story/MissionRules.lua','scripts/story/MissionTimers.lua','scripts/story/HoldRules.lua','scripts/story/ConvoyRules.lua',
 'tools/migration/check-story-mission-timers-native.lua','tools/migration/verify-story-mission-timers-native.ps1','tools/migration/entries/body-arm.lua')
function ProbeHashes {
    $hashes=[ordered]@{}
    foreach($file in $files){$hashes[$file]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $file) -Algorithm SHA256).Hash}
    return $hashes
}
$manifest=[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');before=ProbeHashes;
 scope='Actual native Node/ScriptObject wall-clock hold and escort retry, choices, event dispatch and later-frame Dispose; no Rules.Step, full mission or Web focus acceptance'}
$result=Join-Path $evidence 'validator.json';$stdout=Join-Path $evidence 'stdout.txt'
$runtimeArgs=@('_mission_timers_native_check.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
 '-validate-frames=650','-validate-timeout=20','-validate-spike-threshold=20000',
 ('-validate-output='+$result),'-log','info',('-validate-test='+$PSScriptRoot+'/check-story-mission-timers-native.lua'))
$state=@{exitCode=$null;timedOut=$false}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'entries/body-arm.lua') -Destination $entry
try {
    $process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput $stdout -RedirectStandardError ($evidence+'/stderr.txt')
    $manifest.probePid=$process.Id;$state=Wait-MissionTimersProcess $process 30
} finally {
    Remove-Item -LiteralPath $entry
    if(Test-Path -LiteralPath ($entry+'.meta')){Remove-Item -LiteralPath ($entry+'.meta')}
}
$manifest.after=ProbeHashes;$manifest.finishedUtc=[DateTime]::UtcNow.ToString('o')
$manifest.runtimeExit=$state.exitCode;$manifest.timedOut=$state.timedOut
$manifest.changedDuringRun=@($files|Where-Object {$manifest.before[$_] -ne $manifest.after[$_]})
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'manifest.json') -Encoding utf8
Write-Output $evidence
if($state.timedOut -or $null -eq $state.exitCode -or $state.exitCode -ne 0 -or $manifest.changedDuringRun.Count){throw 'Native probe failed, timed out, or inputs changed.'}
if(-not(Test-Path -LiteralPath $result)){throw 'Native probe emitted no validator report.'}
$native=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json
$native|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
Assert-MissionTimersEvidence $native (Get-Content -LiteralPath $stdout -Raw)
