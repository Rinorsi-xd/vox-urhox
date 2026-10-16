param(
 [string]$Snapshot='D:/Rino_Project/maker/Vox/VoxelCraft/.tmp/outgame-cached-1792120761228',
 [string]$Fingerprint='c4a4000bf69965adce81a8512618b3e67af2a6aa186454483625b48e37b6aaf0',
 [switch]$ExclusiveNativeWindow,[switch]$PrepareOnly,[switch]$SelfTest
)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
function Write-ImpactFixture([string]$Target,[string]$Folder){
 $source=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'check-comic-impact-native.lua') -Raw
 if(-not $source.Contains('__EVIDENCE__')){throw 'Owned fixture output placeholder missing.'}
 [IO.File]::WriteAllText($Target,$source.Replace('__EVIDENCE__',$Folder.Replace('\','/')),[Text.UTF8Encoding]::new($false))
 & $python (Join-Path $PSScriptRoot 'check-comic-impact-fixture.py') $Target
 if($LASTEXITCODE -ne 0){throw 'Generated actual Lua fixture failed CPU execution.'}
}
function Assert-ImpactEvidence($Native,[string]$Log,$State,[int]$Changed){
 if($State.timedOut -or $null -eq $State.exitCode -or $State.exitCode -ne 0 -or $Changed -ne 0 -or
  $Native.result -ne 'PASS' -or $Native.test_result -ne 'PASSED' -or
  $null -eq $Native.summary.total_errors -or $Native.summary.total_errors -ne 0 -or
  $Native.test_assertions.total -ne 60 -or $Native.test_assertions.passed -ne 60 -or
  $null -eq $Native.test_assertions.failed -or $Native.test_assertions.failed -ne 0 -or
  -not $Log.Contains('[ComicImpactRaster] started') -or -not $Log.Contains('[ComicImpactRaster] completed 60 checks;')){
  throw 'Comic raster requires exact 60/60 assertions, zero errors, exit 0, no timeout, both markers and unchanged inputs.'
 }
 foreach($size in @('1920x1080','2400x1080','1440x1080','1333x600')){foreach($kind in @('no','bang')){
  if(-not $Log.Contains('[ComicImpactRaster] shot '+$size+'-'+$kind+' ')){throw 'Missing actual raster case marker.'}
 }}
}
if($SelfTest){
 $valid='{"result":"PASS","test_result":"PASSED","summary":{"total_errors":0},"test_assertions":{"total":60,"passed":60,"failed":0}}'
 $log='[ComicImpactRaster] started [ComicImpactRaster] completed 60 checks;'
 foreach($s in @('1920x1080','2400x1080','1440x1080','1333x600')){foreach($k in @('no','bang')){$log+='[ComicImpactRaster] shot '+$s+'-'+$k+' '}}
 $ok=@{exitCode=0;timedOut=$false};Assert-ImpactEvidence ($valid|ConvertFrom-Json) $log $ok 0
 $cases=@(
  @{json=$valid.Replace('60','0');log=$log;state=$ok;changed=0},
  @{json=$valid.Replace('"passed":60','"passed":59');log=$log;state=$ok;changed=0},
  @{json=$valid.Replace('"failed":0','"failed":1');log=$log;state=$ok;changed=0},
  @{json=$valid.Replace('"total_errors":0','"total_errors":1');log=$log;state=$ok;changed=0},
  @{json=$valid.Replace('"result":"PASS"','"result":"FAIL"');log=$log;state=$ok;changed=0},
  @{json=$valid;log=$log.Replace('[ComicImpactRaster] started','');state=$ok;changed=0},
  @{json=$valid;log=$log.Replace('[ComicImpactRaster] completed 60 checks;','');state=$ok;changed=0},
  @{json=$valid;log=$log.Replace('[ComicImpactRaster] shot 1333x600-bang ','');state=$ok;changed=0},
  @{json=$valid;log=$log;state=@{exitCode=7;timedOut=$false};changed=0},
  @{json=$valid;log=$log;state=@{exitCode=$null;timedOut=$false};changed=0},
  @{json=$valid;log=$log;state=@{exitCode=0;timedOut=$true};changed=0},
  @{json=$valid;log=$log;state=$ok;changed=1}
 )
 foreach($case in $cases){$rejected=$false;try{Assert-ImpactEvidence ($case.json|ConvertFrom-Json) $case.log $case.state $case.changed}catch{$rejected=$true};if(-not $rejected){throw 'Incomplete raster evidence escaped gate.'}}
 $fixture=Join-Path ([IO.Path]::GetTempPath()) ('vox-comic-impact-'+[guid]::NewGuid().ToString('N')+'.lua')
 try{Write-ImpactFixture $fixture 'unused-comic-raster'}finally{if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture}}
 Write-Output 'CPU PASS: 1 positive / 12 negative evidence gates and real Lua fixture registration/BOM negative. No GPU launched.';return
}
if(-not $PrepareOnly -and -not $ExclusiveNativeWindow){throw 'Only root may allocate exclusive native GPU execution.'}
$Snapshot=(Resolve-Path -LiteralPath $Snapshot).Path
$identity=Get-Content -LiteralPath (Join-Path $Snapshot 'identity.json') -Raw|ConvertFrom-Json
if(-not $identity.ok -or $identity.identity.scriptFingerprint -ne $Fingerprint){throw 'Frozen final build identity mismatch.'}
$files=@('identity.json','scripts/ui/IntroComicText.lua','scripts/ui/IntroGlyphs.lua','scripts/ui/IntroOpacity.lua','scripts/ui/SourceDraw.lua','scripts/ui/SourceFonts.lua','scripts/ui/SourceTextLayout.lua','scripts/core/ResourceData.lua','assets/Intro/Fonts/TitleGlyphs.json','assets/Fonts/BarlowCondensed-BoldItalic.ttf','assets/Fonts/VoxDisplayTabular-BoldItalic.ttf','assets/Fonts/VoxIndustrial-Bold.otf','assets/UI/SourceIcons.json')
foreach($entry in $identity.identity.scripts.PSObject.Properties){
 $actual=(Get-FileHash -LiteralPath (Join-Path $Snapshot ('scripts/'+$entry.Name)) -Algorithm SHA256).Hash
 if($actual -ne $entry.Value){throw ('Frozen build Lua drift: '+$entry.Name)}
}
function ImpactHashes{$out=[ordered]@{};foreach($f in $files){$out[$f]=(Get-FileHash -LiteralPath (Join-Path $Snapshot $f) -Algorithm SHA256).Hash};return $out}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $taskRoot ('docs/migration/evidence/comic-impact-native-'+$stamp)
New-Item -ItemType Directory -Path $evidence|Out-Null
$test=Join-Path $evidence 'fixture.lua';Write-ImpactFixture $test $evidence
$manifest=[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');snapshot=$Snapshot;fingerprint=$Fingerprint;before=ImpactHashes;fixtureBefore=(Get-FileHash -LiteralPath $test -Algorithm SHA256).Hash;scope='Final production No/Bang native raster at four logical viewports, letterboxed into actual physical window. Eight images; no natural opening/audio/performance acceptance.'}
$project=Join-Path $evidence 'isolated-project'
$copied=@('scripts/ui/IntroComicText.lua','scripts/ui/IntroGlyphs.lua','scripts/ui/IntroOpacity.lua','scripts/ui/SourceDraw.lua','scripts/ui/SourceTextLayout.lua','scripts/core/ResourceData.lua','assets/Intro/Fonts/TitleGlyphs.json','assets/UI/SourceIcons.json','assets/Fonts/MiSans-Regular.ttf','assets/Fonts/VoxIndustrial-Bold.otf')
$closure=[ordered]@{}
foreach($file in $copied){
 $target=Join-Path $project $file;New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
 Copy-Item -LiteralPath (Join-Path $Snapshot $file) -Destination $target
 $copyHash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
 if($copyHash -ne (Get-FileHash -LiteralPath (Join-Path $Snapshot $file) -Algorithm SHA256).Hash){throw 'Isolated final-build input copy drift.'}
 $closure[$file]=$copyHash
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'comic-impact-main.lua') -Destination (Join-Path $project 'scripts/main.lua')
New-Item -ItemType Directory -Path (Join-Path $project '.project') -Force|Out-Null
$settings='{"build":{"asset_dirs":["../assets","../scripts"]},"@runtime":{"multiplayer":{"enabled":false}}}'
[IO.File]::WriteAllText((Join-Path $project '.project/settings.json'),$settings,[Text.UTF8Encoding]::new($false))
$manifest.isolatedProject=@{directory=$project;copiedFinalInputs=$closure;mainSha256=(Get-FileHash -LiteralPath (Join-Path $project 'scripts/main.lua') -Algorithm SHA256).Hash;scope='Only six final production Lua modules, two JSON inputs, startup MiSans/UI industrial fonts and QA UI-only main. GameFont contours render directly: no SourceDraw.Begin required.'}
& $python (Join-Path $PSScriptRoot 'check-comic-impact-fixture.py') $test $project
if($LASTEXITCODE -ne 0){throw 'Isolated project CPU lifecycle/mount check failed.'}
$manifest|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $evidence 'manifest.json') -Encoding utf8
if($PrepareOnly){Write-Output $evidence;Write-Output 'Prepared CPU-only fixture. No GPU launched.';return}
$editorRuntime=Get-CimInstance Win32_Process|Where-Object {$_.Name -eq 'UrhoXEditor.exe' -and $_.ExecutablePath -match '[\\/]versions[\\/]'}|Select-Object -First 1
if($null -eq $editorRuntime){throw 'Installed editor runtime required for actual SDK dependency.'}
$sdkDirectory=Split-Path -Parent $editorRuntime.ExecutablePath;$sdk=Join-Path $sdkDirectory 'themis_x64.dll'
if(-not(Test-Path -LiteralPath $sdk)){throw 'Actual SDK dependency missing.'}
$environmentSource=Join-Path $Snapshot 'assets/Cube/Day/DaySpecularHDR.dds';$environmentTarget=Join-Path $taskRoot '.cli/Res/Cube/Day/DaySpecularHDR.dds'
$manifest.startupDependencies=@{sdk=$sdk;sdkSha256=(Get-FileHash -LiteralPath $sdk -Algorithm SHA256).Hash;environment=$environmentSource;environmentSha256=(Get-FileHash -LiteralPath $environmentSource -Algorithm SHA256).Hash}
$result=Join-Path $evidence 'validator.json';$stdout=Join-Path $evidence 'stdout.txt'
$taskArgs=@('main.lua',('-tapcode_dir='+$project),'-tool_mode','-validate','-validate-frames=38','-validate-timeout=60','-validate-spike-threshold=100',('-validate-output='+$result),'-log','info',('-validate-test='+$test))
$originalPath=$env:PATH;$createdEnvironment=$false;$state=@{exitCode=$null;timedOut=$false};$launchError=$null
try{
 if(-not(Test-Path -LiteralPath $environmentTarget)){New-Item -ItemType Directory -Path (Split-Path -Parent $environmentTarget) -Force|Out-Null;Copy-Item -LiteralPath $environmentSource -Destination $environmentTarget;$createdEnvironment=$true}
 $env:PATH=$sdkDirectory+';'+$originalPath
 $process=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput $stdout -RedirectStandardError ($evidence+'/stderr.txt')
 $env:PATH=$originalPath;$null=$process.Handle;$manifest.probePid=$process.Id;$deadline=[DateTime]::UtcNow.AddSeconds(75)
 while(-not $process.WaitForExit(250)){if([DateTime]::UtcNow -ge $deadline){$state.timedOut=$true;$process.Kill();break}}
 $process.WaitForExit();$state.exitCode=$process.ExitCode
}catch{$launchError=$_.Exception.Message}finally{
 $env:PATH=$originalPath;if($createdEnvironment){Remove-Item -LiteralPath $environmentTarget}
 $manifest.after=ImpactHashes;$manifest.finishedUtc=[DateTime]::UtcNow.ToString('o');$manifest.runtimeExit=$state.exitCode;$manifest.timedOut=$state.timedOut;$manifest.launchError=$launchError
 $manifest.fixtureAfter=(Get-FileHash -LiteralPath $test -Algorithm SHA256).Hash;$manifest.changedDuringRun=@($files|Where-Object {$manifest.before[$_] -ne $manifest.after[$_]})
 if($manifest.fixtureBefore -ne $manifest.fixtureAfter){$manifest.changedDuringRun+=@('evidence fixture.lua')}
 $manifest|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $evidence 'manifest.json') -Encoding utf8;Write-Output $evidence
}
if($launchError){throw $launchError};if(-not(Test-Path -LiteralPath $result)){throw 'Native validator output missing.'}
$native=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json
$stdoutText=Get-Content -LiteralPath $stdout -Raw;$officialLog=[regex]::Match($stdoutText,'Lua official log file initialized: ([^\r\n]+)')
if(-not $officialLog.Success){throw 'Missing official per-run script log announcement.'}
$scriptLogPath=[IO.Path]::GetFullPath($officialLog.Groups[1].Value.Trim());$logRoot=[IO.Path]::GetFullPath((Join-Path $taskRoot '.cli/logs/lua'))+[IO.Path]::DirectorySeparatorChar
if(-not $scriptLogPath.StartsWith($logRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Announced script log outside runtime log root.'}
$scriptLog=Get-Item -LiteralPath $scriptLogPath
if($scriptLog.CreationTimeUtc -lt [DateTime]::Parse($manifest.startedUtc).ToUniversalTime().AddSeconds(-1)){throw 'Script log predates current run.'}
$scriptLogText=Get-Content -LiteralPath $scriptLogPath -Raw;Copy-Item -LiteralPath $scriptLogPath -Destination (Join-Path $evidence 'script-log.jsonl')
$manifest.scriptLog=@{source=$scriptLogPath;sha256=(Get-FileHash -LiteralPath $scriptLogPath -Algorithm SHA256).Hash}
$manifest|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $evidence 'manifest.json') -Encoding utf8
$native|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
Assert-ImpactEvidence $native $scriptLogText $state $manifest.changedDuringRun.Count
& $python (Join-Path $PSScriptRoot 'check-comic-impact-pixels.py') $evidence
if($LASTEXITCODE -ne 0){throw 'Actual screenshots failed pixel/dimension inspection.'}
