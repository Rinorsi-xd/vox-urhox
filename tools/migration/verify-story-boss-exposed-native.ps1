param([switch]$ExclusiveNativeWindow,[switch]$SelfTest)
$ErrorActionPreference='Stop'

function Wait-BossExposedProcess($Process,[int]$TimeoutSeconds) {
    # Pin the handle while the child is alive so Windows PowerShell retains its exit status.
    $null=$Process.Handle
    $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $timedOut=$false
    while(-not $Process.WaitForExit(500)){
        if([DateTime]::UtcNow -ge $deadline){$timedOut=$true;$Process.Kill();break}
    }
    $Process.WaitForExit()
    $exitCode=$Process.ExitCode
    if($null -eq $exitCode){throw 'Child exited without a readable exit status.'}
    return @{exitCode=$exitCode;timedOut=$timedOut}
}

function Assert-BossExposedEvidence($Native,[string]$Log) {
    if($Native.result -ne 'PASS' -or $Native.test_result -ne 'PASSED' -or
       $null -eq $Native.summary.total_errors -or $Native.summary.total_errors -ne 0 -or
       $Native.test_assertions.total -ne 14 -or $Native.test_assertions.passed -ne 14 -or
       $null -eq $Native.test_assertions.failed -or $Native.test_assertions.failed -ne 0 -or
       -not $Log.Contains('[BossExposedNative] started') -or
       -not $Log.Contains('[BossExposedNative] completed 14 checks;')) {
        throw 'Boss timer native fixture requires exactly 14 passed assertions, zero errors and both execution markers.'
    }
}

if($SelfTest){
    $valid='{"result":"PASS","test_result":"PASSED","summary":{"total_errors":0},"test_assertions":{"total":14,"passed":14,"failed":0}}'
    $log='[BossExposedNative] started [BossExposedNative] completed 14 checks;'
    Assert-BossExposedEvidence ($valid|ConvertFrom-Json) $log
    $cases=@(
        @{json=$valid.Replace('14','0');log=$log},
        @{json=$valid.Replace('"passed":14','"passed":13');log=$log},
        @{json=$valid.Replace('"failed":0','"failed":1');log=$log},
        @{json=$valid.Replace('"total_errors":0','"total_errors":1');log=$log},
        @{json=$valid.Replace('"result":"PASS"','"result":"FAIL"');log=$log},
        @{json=$valid;log='[BossExposedNative] started'},
        @{json=$valid;log='[BossExposedNative] completed 14 checks;'}
    )
    foreach($case in $cases){
        $rejected=$false
        try {Assert-BossExposedEvidence ($case.json|ConvertFrom-Json) $case.log} catch {$rejected=$true}
        if(-not $rejected){throw 'Evidence gate accepted an incomplete or failed fixture.'}
    }
    foreach($expectedExit in @(0,7)){
        $child=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile','-Command',('Start-Sleep -Milliseconds 150; exit '+$expectedExit))
        $childState=Wait-BossExposedProcess $child 10
        if($childState.timedOut -or $childState.exitCode -ne $expectedExit){throw 'Child-process exit status control failed.'}
    }
    Write-Output 'Boss exposed native evidence gate: 1 positive, 7 negative and 2 real process exit controls PASS; no native runtime launched.'
    return
}

if(-not $ExclusiveNativeWindow){throw 'Root must allocate the exclusive native window.'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$entry=Join-Path $projectRoot 'scripts/_boss_exposed_native_check.lua'
if((Test-Path -LiteralPath $entry) -or (Test-Path -LiteralPath ($entry+'.meta'))){throw 'Boss timer fixture temporary entry already exists.'}
if(-not(Test-Path -LiteralPath (Join-Path $projectRoot 'scripts/combat/BossExposedDelay.lua'))){throw 'Integrate the reviewed Boss delay module before native validation.'}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/story-boss-exposed-native-'+$stamp)
New-Item -ItemType Directory -Path $evidence | Out-Null
$files=@('scripts/combat/BossExposedDelay.lua','scripts/combat/StoryBoss.lua','scripts/story/BossRules.lua',
    'tools/migration/check-story-boss-exposed-native.lua','tools/migration/verify-story-boss-exposed-native.ps1','tools/migration/entries/body-arm.lua')
function ProbeHashes {
    $hashes=[ordered]@{}
    foreach($file in $files){$hashes[$file]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $file) -Algorithm SHA256).Hash}
    return $hashes
}
$manifest=[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');before=ProbeHashes;
    scope='Real native Node/ScriptObject global Update wall-clock delay and disposal; no Boss.Update, full mission, Web focus or audio acceptance'}
$result=Join-Path $evidence 'validator.json'
$stdout=Join-Path $evidence 'stdout.txt'
$runtimeArgs=@('_boss_exposed_native_check.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
    '-validate-frames=650','-validate-timeout=20','-validate-spike-threshold=20000',
    ('-validate-output='+$result),'-log','info',('-validate-test='+$PSScriptRoot+'/check-story-boss-exposed-native.lua'))
$processState=@{exitCode=$null;timedOut=$false}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'entries/body-arm.lua') -Destination $entry
try {
    $process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput $stdout -RedirectStandardError ($evidence+'/stderr.txt')
    $manifest.probePid=$process.Id
    $processState=Wait-BossExposedProcess $process 30
} finally {
    Remove-Item -LiteralPath $entry
    if(Test-Path -LiteralPath ($entry+'.meta')){Remove-Item -LiteralPath ($entry+'.meta')}
}
$manifest.after=ProbeHashes
$manifest.finishedUtc=[DateTime]::UtcNow.ToString('o');$manifest.runtimeExit=$processState.exitCode;$manifest.timedOut=$processState.timedOut
$manifest.changedDuringRun=@($files|Where-Object {$manifest.before[$_] -ne $manifest.after[$_]})
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'manifest.json') -Encoding utf8
Write-Output $evidence
if($processState.timedOut -or $null -eq $processState.exitCode -or $processState.exitCode -ne 0 -or $manifest.changedDuringRun.Count){throw 'Native probe timed out, failed, or inputs changed.'}
if(-not(Test-Path -LiteralPath $result)){throw 'Native probe emitted no validator report.'}
$native=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json
$native|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
Assert-BossExposedEvidence $native (Get-Content -LiteralPath $stdout -Raw)
