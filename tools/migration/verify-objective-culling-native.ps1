param([switch]$ExclusiveNativeWindow,[switch]$SelfTest)
$ErrorActionPreference='Stop'

function Wait-ObjectiveProcess($Process,[int]$TimeoutSeconds) {
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

function Assert-ObjectiveEvidence($Native,[string]$Log) {
    if($Native.result -ne 'PASS' -or $Native.test_result -ne 'PASSED' -or
       $null -eq $Native.summary.total_errors -or $Native.summary.total_errors -ne 0 -or
       $Native.test_assertions.total -ne 16 -or $Native.test_assertions.passed -ne 16 -or
       $null -eq $Native.test_assertions.failed -or $Native.test_assertions.failed -ne 0 -or
       -not $Log.Contains('[ObjectiveCullingNative] started') -or
       -not $Log.Contains('[ObjectiveCullingNative] completed 16 checks;')) {
        throw 'Objective native fixture requires exactly 16 passed assertions, zero errors and both execution markers.'
    }
}

if($SelfTest){
    $valid='{"result":"PASS","test_result":"PASSED","summary":{"total_errors":0},"test_assertions":{"total":16,"passed":16,"failed":0}}'
    $log='[ObjectiveCullingNative] started [ObjectiveCullingNative] completed 16 checks;'
    Assert-ObjectiveEvidence ($valid|ConvertFrom-Json) $log
    $cases=@(
        @{json=$valid.Replace('16','0');log=$log},
        @{json=$valid.Replace('"passed":16','"passed":15');log=$log},
        @{json=$valid.Replace('"failed":0','"failed":1');log=$log},
        @{json=$valid.Replace('"total_errors":0','"total_errors":1');log=$log},
        @{json=$valid.Replace('"result":"PASS"','"result":"FAIL"');log=$log},
        @{json=$valid;log='[ObjectiveCullingNative] started'},
        @{json=$valid;log='[ObjectiveCullingNative] completed 16 checks;'}
    )
    foreach($case in $cases){
        $rejected=$false
        try {Assert-ObjectiveEvidence ($case.json|ConvertFrom-Json) $case.log} catch {$rejected=$true}
        if(-not $rejected){throw 'Evidence gate accepted an incomplete or failed fixture.'}
    }
    foreach($expectedExit in @(0,7)){
        $child=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile','-Command',('Start-Sleep -Milliseconds 150; exit '+$expectedExit))
        $childState=Wait-ObjectiveProcess $child 10
        if($childState.timedOut -or $childState.exitCode -ne $expectedExit){throw 'Child-process exit status control failed.'}
    }
    Write-Output 'Objective native evidence gate: 1 positive, 7 negative and 2 real process exit controls PASS; no native runtime launched.'
    return
}

if(-not $ExclusiveNativeWindow){throw 'Root must allocate the exclusive native window.'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$entry=Join-Path $projectRoot 'scripts/_objective_culling_native_check.lua'
if((Test-Path -LiteralPath $entry) -or (Test-Path -LiteralPath ($entry+'.meta'))){throw 'Objective fixture temporary entry already exists.'}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/objective-culling-native-'+$stamp)
New-Item -ItemType Directory -Path $evidence | Out-Null
$files=@('scripts/render/ObjectiveView.lua','scripts/render/ObjectiveRoute.lua','scripts/core/Coord.lua',
    'tools/migration/check-objective-culling-native.lua','tools/migration/verify-objective-culling-native.ps1','tools/migration/entries/body-arm.lua')
function ProbeHashes {
    $hashes=[ordered]@{}
    foreach($file in $files){$hashes[$file]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $file) -Algorithm SHA256).Hash}
    return $hashes
}
$manifest=[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');before=ProbeHashes;
    scope='Real native Camera.frustum/BoundingBox/CustomGeometry only; not Web, full-match pixels or performance acceptance'}
$result=Join-Path $evidence 'validator.json'
$stdout=Join-Path $evidence 'stdout.txt'
$runtimeArgs=@('_objective_culling_native_check.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
    '-validate-frames=10','-validate-timeout=20','-validate-spike-threshold=20000',
    ('-validate-output='+$result),'-log','info',('-validate-test='+$PSScriptRoot+'/check-objective-culling-native.lua'))
$processState=@{exitCode=$null;timedOut=$false}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'entries/body-arm.lua') -Destination $entry
try {
    $process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput $stdout -RedirectStandardError ($evidence+'/stderr.txt')
    $manifest.probePid=$process.Id
    $processState=Wait-ObjectiveProcess $process 30
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
Assert-ObjectiveEvidence $native (Get-Content -LiteralPath $stdout -Raw)
