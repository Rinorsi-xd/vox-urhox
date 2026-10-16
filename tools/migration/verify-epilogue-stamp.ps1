param([switch]$ExclusiveNativeWindow,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
function Write-StampFixture([string]$Target,[string]$ImagePath) {
    $fixture=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'check-epilogue-stamp.lua') -Raw
    $oldImage='docs/migration/evidence/epilogue-stamp-native.png'
    if(-not $fixture.Contains($oldImage)){throw 'Expected owned stamp screenshot path missing.'}
    $fixture=$fixture.Replace($oldImage,$ImagePath)
    $marker="print('[EpilogueStampNative] started')`nlocal stampFinish=V.finish`nV.finish=function(...) print('[EpilogueStampNative] completed 11 checks;');return stampFinish(...) end`n"
    [IO.File]::WriteAllText($Target,$marker+$fixture,[Text.UTF8Encoding]::new($false))
}
function Test-StampFixtureLoad([string]$FixturePath) {
    $python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if(-not(Test-Path -LiteralPath $python)){throw 'Bundled Python is required for actual Lua fixture load validation.'}
    & $python (Join-Path $PSScriptRoot 'check-stamp-fixture-load.py') $FixturePath $taskRoot
    if($LASTEXITCODE -ne 0){throw 'Generated native stamp fixture failed actual CPU Lua load/execution.'}
}
function Wait-StampProcess($Process,[int]$TimeoutSeconds) {
    $null=$Process.Handle
    $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds);$timedOut=$false
    while(-not $Process.WaitForExit(250)){
        if([DateTime]::UtcNow -ge $deadline){$timedOut=$true;$Process.Kill();break}
    }
    $Process.WaitForExit()
    return @{exitCode=$Process.ExitCode;timedOut=$timedOut}
}
function Assert-StampEvidence($Native,[string]$Log,$State,[int]$Changed) {
    if($State.timedOut -or $null -eq $State.exitCode -or $State.exitCode -ne 0 -or $Changed -ne 0 -or
       $Native.result -ne 'PASS' -or $Native.test_result -ne 'PASSED' -or
       $null -eq $Native.summary.total_errors -or $Native.summary.total_errors -ne 0 -or
       $Native.test_assertions.total -ne 11 -or $Native.test_assertions.passed -ne 11 -or
       $null -eq $Native.test_assertions.failed -or $Native.test_assertions.failed -ne 0 -or
       -not $Log.Contains('[EpilogueStampNative] started') -or
       -not $Log.Contains('[EpilogueStampNative] completed 11 checks;')) {
        throw 'Stamp requires 11 passed assertions, zero errors, both execution markers, exit 0 and unchanged inputs.'
    }
}
if($SelfTest){
    $valid='{"result":"PASS","test_result":"PASSED","summary":{"total_errors":0},"test_assertions":{"total":11,"passed":11,"failed":0}}'
    $log='[EpilogueStampNative] started [EpilogueStampNative] completed 11 checks;'
    $ok=@{exitCode=0;timedOut=$false}
    Assert-StampEvidence ($valid|ConvertFrom-Json) $log $ok 0
    $cases=@(
        @{json=$valid.Replace('11','0');log=$log;state=$ok;changed=0},
        @{json=$valid.Replace('"passed":11','"passed":10');log=$log;state=$ok;changed=0},
        @{json=$valid.Replace('"failed":0','"failed":1');log=$log;state=$ok;changed=0},
        @{json=$valid.Replace('"total_errors":0','"total_errors":1');log=$log;state=$ok;changed=0},
        @{json=$valid.Replace('"result":"PASS"','"result":"FAIL"');log=$log;state=$ok;changed=0},
        @{json=$valid;log='[EpilogueStampNative] started';state=$ok;changed=0},
        @{json=$valid;log='[EpilogueStampNative] completed 11 checks;';state=$ok;changed=0},
        @{json=$valid;log=$log;state=@{exitCode=7;timedOut=$false};changed=0},
        @{json=$valid;log=$log;state=@{exitCode=$null;timedOut=$false};changed=0},
        @{json=$valid;log=$log;state=@{exitCode=0;timedOut=$true};changed=0},
        @{json=$valid;log=$log;state=$ok;changed=1}
    )
    foreach($case in $cases){
        $rejected=$false
        try{Assert-StampEvidence ($case.json|ConvertFrom-Json) $case.log $case.state $case.changed}catch{$rejected=$true}
        if(-not $rejected){throw 'Stamp evidence gate accepted incomplete evidence.'}
    }
    $shell=(Get-Process -Id $PID).Path
    foreach($expectedExit in @(0,7)){
        $child=Start-Process -FilePath $shell -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile','-Command',('Start-Sleep -Milliseconds 100; exit '+$expectedExit))
        $state=Wait-StampProcess $child 10
        if($state.timedOut -or $state.exitCode -ne $expectedExit){throw 'Stamp process exit control failed.'}
    }
    $child=Start-Process -FilePath $shell -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 3')
    $state=Wait-StampProcess $child 1
    if(-not $state.timedOut -or $null -eq $state.exitCode){throw 'Stamp timeout capture control failed.'}
    $cpuFixture=Join-Path ([IO.Path]::GetTempPath()) ('vox-stamp-fixture-'+[guid]::NewGuid().ToString('N')+'.lua')
    try {Write-StampFixture $cpuFixture 'unused-cpu-stamp.png';Test-StampFixtureLoad $cpuFixture} finally {if(Test-Path -LiteralPath $cpuFixture){Remove-Item -LiteralPath $cpuFixture}}
    Write-Output 'Stamp gate: 1 positive, 11 negatives, 2 process exits, 1 timeout and real generated Lua fixture load/BOM negative PASS. No GPU launched.'
    return
}
if(-not $ExclusiveNativeWindow){throw 'Root must allocate the exclusive native GPU window.'}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $taskRoot ('docs/migration/evidence/epilogue-stamp-native-'+$stamp)
New-Item -ItemType Directory -Path $evidence|Out-Null
$files=@('scripts/ui/Epilogue.lua','scripts/ui/EpilogueMotion.lua','scripts/story/EpilogueRules.lua','assets/Story/Boss/Epilogue.json',
 'scripts/ui/IntroTypography.lua','scripts/ui/SourceDraw.lua','scripts/ui/WorkshopPaint.lua','scripts/ui/CommsCard.lua',
 'scripts/audio/StoryComms.lua','scripts/audio/StoryRadio.lua','tools/migration/check-epilogue-stamp.lua','tools/migration/verify-epilogue-stamp.ps1',
 'tools/migration/check-stamp-fixture-load.py','assets/Cube/Day/DaySpecularHDR.dds')
function StampHashes {
    $hashes=[ordered]@{};foreach($file in $files){$hashes[$file]=(Get-FileHash -LiteralPath (Join-Path $taskRoot $file) -Algorithm SHA256).Hash};return $hashes
}
$test=Join-Path $evidence 'fixture.lua'
Write-StampFixture $test ('docs/migration/evidence/epilogue-stamp-native-'+$stamp+'/stamp.png')
Test-StampFixtureLoad $test
$testHash=(Get-FileHash -LiteralPath $test -Algorithm SHA256).Hash
$manifest=[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');before=StampHashes;fixtureBefore=$testHash;
 scope='Actual isolated native Epilogue rendering: screenshot bridge, hidden comics under final stamp, stamp pixels and idempotent cleanup. Not natural fifth mission, complete ending animation, Web, listening or mobile performance.'}
$result=Join-Path $evidence 'validator.json';$stdout=Join-Path $evidence 'stdout.txt'
$taskArgs=@('main.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate','-validate-frames=52','-validate-timeout=60','-validate-spike-threshold=100',('-validate-output='+$result),'-log','info',('-validate-test='+$test))
$state=@{exitCode=$null;timedOut=$false};$launchError=$null
$editorRuntime=Get-CimInstance Win32_Process | Where-Object {$_.Name -eq 'UrhoXEditor.exe' -and $_.ExecutablePath -match '[\\/]versions[\\/]'} | Select-Object -First 1
if($null -eq $editorRuntime){throw 'Installed editor runtime is required for the real Themis SDK dependency.'}
$sdkDirectory=Split-Path -Parent $editorRuntime.ExecutablePath
$sdk=Join-Path $sdkDirectory 'themis_x64.dll'
if(-not(Test-Path -LiteralPath $sdk)){throw ('Installed editor SDK dependency is missing: '+$sdk)}
$environmentSource=Join-Path $taskRoot 'assets/Cube/Day/DaySpecularHDR.dds'
$environmentTarget=Join-Path $taskRoot '.cli/Res/Cube/Day/DaySpecularHDR.dds'
$createdEnvironment=$false;$originalPath=$env:PATH
$manifest.startupDependencies=@{sdk=$sdk;sdkSha256=(Get-FileHash -LiteralPath $sdk -Algorithm SHA256).Hash;environment=$environmentSource;environmentSha256=(Get-FileHash -LiteralPath $environmentSource -Algorithm SHA256).Hash;temporaryEnvironmentTarget=$environmentTarget}
try {
    if(-not(Test-Path -LiteralPath $environmentTarget)){
        New-Item -ItemType Directory -Path (Split-Path -Parent $environmentTarget) -Force|Out-Null
        Copy-Item -LiteralPath $environmentSource -Destination $environmentTarget;$createdEnvironment=$true
    }
    $env:PATH=$sdkDirectory+';'+$originalPath
    $process=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput $stdout -RedirectStandardError ($evidence+'/stderr.txt')
    $env:PATH=$originalPath
    $manifest.probePid=$process.Id;$state=Wait-StampProcess $process 75
} catch {$launchError=$_.Exception.Message} finally {
    $env:PATH=$originalPath
    if($createdEnvironment){Remove-Item -LiteralPath $environmentTarget}
    $manifest.after=StampHashes;$manifest.finishedUtc=[DateTime]::UtcNow.ToString('o')
    $manifest.runtimeExit=$state.exitCode;$manifest.timedOut=$state.timedOut;$manifest.launchError=$launchError
    $manifest.fixtureAfter=(Get-FileHash -LiteralPath $test -Algorithm SHA256).Hash
    $manifest.changedDuringRun=@($files|Where-Object {$manifest.before[$_] -ne $manifest.after[$_]})
    if($manifest.fixtureBefore -ne $manifest.fixtureAfter){$manifest.changedDuringRun+=@('evidence fixture.lua')}
    $manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'manifest.json') -Encoding utf8
    Write-Output $evidence
}
if($launchError){throw $launchError}
if(-not(Test-Path -LiteralPath $result)){throw 'No native stamp validator output; manifest retains exit/timeout evidence.'}
$native=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json
$native|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
$stdoutText=Get-Content -LiteralPath $stdout -Raw
$officialLog=[regex]::Match($stdoutText,'Lua official log file initialized: ([^\r\n]+)')
if(-not $officialLog.Success){throw 'Runtime did not announce a per-run Lua script log.'}
$scriptLogPath=[IO.Path]::GetFullPath($officialLog.Groups[1].Value.Trim())
$logRoot=[IO.Path]::GetFullPath((Join-Path $taskRoot '.cli/logs/lua'))+[IO.Path]::DirectorySeparatorChar
if(-not $scriptLogPath.StartsWith($logRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Runtime announced a script log outside its own log root.'}
$scriptLog=Get-Item -LiteralPath $scriptLogPath
if($scriptLog.CreationTimeUtc -lt [DateTime]::Parse($manifest.startedUtc).ToUniversalTime().AddSeconds(-1)){throw 'Runtime script log predates this run.'}
$scriptLogText=Get-Content -LiteralPath $scriptLogPath -Raw
Copy-Item -LiteralPath $scriptLogPath -Destination (Join-Path $evidence 'script-log.jsonl')
$manifest.scriptLog=@{source=$scriptLogPath;sha256=(Get-FileHash -LiteralPath $scriptLogPath -Algorithm SHA256).Hash;createdUtc=$scriptLog.CreationTimeUtc.ToString('o')}
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'manifest.json') -Encoding utf8
Assert-StampEvidence $native $scriptLogText $state $manifest.changedDuringRun.Count
