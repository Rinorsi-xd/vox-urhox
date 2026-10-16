param([switch]$ExclusiveNativeWindow,[switch]$SelfTest)
$ErrorActionPreference='Stop'
function Assert-CaptureEvidence($Native,[string]$Log) {
 if($Native.result -ne 'PASS' -or $Native.test_result -ne 'PASSED' -or
    $null -eq $Native.summary.total_errors -or $Native.summary.total_errors -ne 0 -or
    $Native.test_assertions.total -ne 20 -or $Native.test_assertions.passed -ne 20 -or
    $null -eq $Native.test_assertions.failed -or $Native.test_assertions.failed -ne 0 -or
    -not $Log.Contains('[BossSceneCaptureNative] started') -or
    -not $Log.Contains('[BossSceneCaptureNative] completed 20 checks;')) {
  throw 'Capture requires exactly 20 passed assertions, zero errors and execution markers.'
 }
}
if($SelfTest){
 $valid='{"result":"PASS","test_result":"PASSED","summary":{"total_errors":0},"test_assertions":{"total":20,"passed":20,"failed":0}}'
 $log='[BossSceneCaptureNative] started [BossSceneCaptureNative] completed 20 checks;'
 Assert-CaptureEvidence ($valid|ConvertFrom-Json) $log
 foreach($bad in @($valid.Replace('20','0'),$valid.Replace('"passed":20','"passed":19'),$valid.Replace('"total_errors":0','"total_errors":1'),$valid.Replace('"failed":0','"failed":1'))){
  $rejected=$false;try{Assert-CaptureEvidence ($bad|ConvertFrom-Json) $log}catch{$rejected=$true};if(-not $rejected){throw 'Incomplete capture evidence accepted.'}
 }
 Write-Output 'Capture evidence gate: 1 positive / 4 negatives PASS. No GPU launched.';return
}
if(-not $ExclusiveNativeWindow){throw 'Root must allocate exclusive GPU window.'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$entry=Join-Path $projectRoot 'scripts/_boss_scene_capture_native_check.lua'
if((Test-Path -LiteralPath $entry) -or (Test-Path -LiteralPath ($entry+'.meta'))){throw 'Temporary capture entry exists.'}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/boss-scene-capture-native-'+$stamp)
New-Item -ItemType Directory -Path $evidence|Out-Null
$files=@('scripts/combat/StoryBoss.lua','scripts/render/BossView.lua','scripts/render/BossSceneCapture.lua','scripts/render/RenderTargetLifetime.lua','tools/migration/check-boss-scene-capture-native.lua','tools/migration/verify-boss-scene-capture-native.ps1','tools/migration/entries/body-arm.lua','assets/Fonts/VoxIndustrial-Bold.otf','assets/Cube/Day/DaySpecularHDR.dds')
function CaptureHashes { $hashes=[ordered]@{};foreach($file in $files){$hashes[$file]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $file) -Algorithm SHA256).Hash};return $hashes }
$manifest=[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');before=CaptureHashes;scope='GPU pixels: bounded 3D-only capture, real NanoVG overlay exclusion, main viewport, delayed capture and cancellation/retirement. No natural S5 or crater post-chain acceptance.'}
$result=Join-Path $evidence 'validator.json';$stdout=Join-Path $evidence 'stdout.txt'
$runtimeArgs=@('_boss_scene_capture_native_check.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=90','-validate-timeout=20','-validate-spike-threshold=20000',('-validate-output='+$result),'-log','info',('-validate-test='+$PSScriptRoot+'/check-boss-scene-capture-native.lua'))
$editorRuntime=Get-CimInstance Win32_Process | Where-Object {$_.Name -eq 'UrhoXEditor.exe' -and $_.ExecutablePath -match '[\\/]versions[\\/]'} | Select-Object -First 1
if($null -eq $editorRuntime){throw 'An installed editor runtime is required to supply the real Themis SDK dependency.'}
$sdkDirectory=Split-Path -Parent $editorRuntime.ExecutablePath
$sdk=Join-Path $sdkDirectory 'themis_x64.dll'
if(-not(Test-Path -LiteralPath $sdk)){throw ('Installed editor SDK dependency is missing: '+$sdk)}
# The CLI initializes its default environment before mounting the project resource root.
$environmentSource=Join-Path $projectRoot 'assets/Cube/Day/DaySpecularHDR.dds'
$environmentTarget=Join-Path $projectRoot '.cli/Res/Cube/Day/DaySpecularHDR.dds'
$createdEnvironment=$false
$originalPath=$env:PATH
$manifest.startupDependencies=@{sdk=$sdk;sdkSha256=(Get-FileHash -LiteralPath $sdk -Algorithm SHA256).Hash;environment=$environmentSource;environmentSha256=(Get-FileHash -LiteralPath $environmentSource -Algorithm SHA256).Hash;temporaryEnvironmentTarget=$environmentTarget}
$exitCode=$null;$timedOut=$false
try{
 if(-not(Test-Path -LiteralPath $environmentTarget)){
  New-Item -ItemType Directory -Path (Split-Path -Parent $environmentTarget) -Force|Out-Null
  Copy-Item -LiteralPath $environmentSource -Destination $environmentTarget;$createdEnvironment=$true
 }
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'entries/body-arm.lua') -Destination $entry
 $env:PATH=$sdkDirectory+';'+$originalPath
 $process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput $stdout -RedirectStandardError ($evidence+'/stderr.txt')
 $env:PATH=$originalPath
 $null=$process.Handle;$manifest.probePid=$process.Id;$deadline=[DateTime]::UtcNow.AddSeconds(30)
 while(-not $process.WaitForExit(500)){if([DateTime]::UtcNow -ge $deadline){$timedOut=$true;$process.Kill();break}}
 $process.WaitForExit();$exitCode=$process.ExitCode
}finally{
 $env:PATH=$originalPath
 if(Test-Path -LiteralPath $entry){Remove-Item -LiteralPath $entry}
 if(Test-Path -LiteralPath ($entry+'.meta')){Remove-Item -LiteralPath ($entry+'.meta')}
 if($createdEnvironment){Remove-Item -LiteralPath $environmentTarget}
}
$manifest.after=CaptureHashes;$manifest.finishedUtc=[DateTime]::UtcNow.ToString('o');$manifest.runtimeExit=$exitCode;$manifest.timedOut=$timedOut
$manifest.changedDuringRun=@($files|Where-Object {$manifest.before[$_] -ne $manifest.after[$_]})
# The runtime's stdout bridge may stop before the script log; use its exact announced per-run log.
$stdoutText=Get-Content -LiteralPath $stdout -Raw
$officialLog=[regex]::Match($stdoutText,'Lua official log file initialized: ([^\r\n]+)')
$scriptLogText=''
if($officialLog.Success){
 $scriptLogPath=[IO.Path]::GetFullPath($officialLog.Groups[1].Value.Trim())
 $logRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot '.cli/logs/lua'))+[IO.Path]::DirectorySeparatorChar
 if(-not $scriptLogPath.StartsWith($logRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Runtime announced a script log outside its own log root.'}
 $scriptLog=Get-Item -LiteralPath $scriptLogPath
 if($scriptLog.CreationTimeUtc -lt [DateTime]::Parse($manifest.startedUtc).ToUniversalTime().AddSeconds(-1)){throw 'Runtime script log predates this native run.'}
 $scriptLogText=Get-Content -LiteralPath $scriptLogPath -Raw
 Copy-Item -LiteralPath $scriptLogPath -Destination (Join-Path $evidence 'script-log.jsonl')
 $manifest.scriptLog=@{source=$scriptLogPath;sha256=(Get-FileHash -LiteralPath $scriptLogPath -Algorithm SHA256).Hash;createdUtc=$scriptLog.CreationTimeUtc.ToString('o')}
}
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'manifest.json') -Encoding utf8
Write-Output $evidence
if($timedOut -or $null -eq $exitCode -or $exitCode -ne 0 -or $manifest.changedDuringRun.Count){throw 'Native capture failed, timed out or inputs changed.'}
if(-not(Test-Path -LiteralPath $result)){throw 'No native capture validator output.'}
$native=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json
$native|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
if(-not $officialLog.Success){throw 'Runtime did not announce a per-run Lua script log.'}
Assert-CaptureEvidence $native $scriptLogText
