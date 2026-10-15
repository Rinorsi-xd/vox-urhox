param(
    [switch]$ExclusiveNativeWindow,
    [string]$ExpectedPointerSha='C55C7FB419B74F00691EA548C7540060AAAFB27708E07629CF11463EA5E28407',
    [string]$ExpectedFilterSha='5F22BEA672B44887641A2A1A4BE4239C1D7C334E7976E06B5E8C39ACC4CE788A'
)
$ErrorActionPreference='Stop'
if(-not $ExclusiveNativeWindow){throw 'Root must allocate the exclusive native window before running this injected-event fixture.'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$runtime=Join-Path $projectRoot '.cli/UrhoXRuntime.exe'
if(-not(Test-Path -LiteralPath $runtime)){throw 'Local native Runtime is absent'}
if((Get-FileHash -LiteralPath (Join-Path $projectRoot 'scripts/controls/DrivePointer.lua')).Hash -ne $ExpectedPointerSha){throw 'DrivePointer does not match frozen candidate'}
if((Get-FileHash -LiteralPath (Join-Path $projectRoot 'scripts/controls/MouseDeltaFilter.lua')).Hash -ne $ExpectedFilterSha){throw 'MouseDeltaFilter does not match frozen candidate'}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/mouse-delta-native-'+$stamp)
New-Item -ItemType Directory -Path $evidence|Out-Null
$files=@('scripts/controls/DrivePointer.lua','scripts/controls/MouseDeltaFilter.lua',
    'tools/migration/source-mouse-delta-golden.cjs','tools/migration/check-mouse-delta-native.lua',
    'tools/migration/verify-mouse-delta-native.ps1','docs/migration/outgame-baseline.json')
function Get-ProbeHashes{
    $hashes=[ordered]@{}
    foreach($file in $files){$hashes[$file]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $file)).Hash}
    return $hashes
}
$before=Get-ProbeHashes
$goldenText=(& node (Join-Path $PSScriptRoot 'source-mouse-delta-golden.cjs'))
if($LASTEXITCODE -ne 0){throw 'Actual frozen H5 mouse golden generation failed'}
$golden=$goldenText|ConvertFrom-Json
$goldenPath=Join-Path $evidence 'source-golden.json'
[IO.File]::WriteAllText($goldenPath,$goldenText,[Text.UTF8Encoding]::new($false))
$manifest=[ordered]@{sourceCommit=$golden.baseline.commit;targetCommit=(& git -C $projectRoot rev-parse HEAD);
    targetBranch=(& git -C $projectRoot branch --show-current);startedUtc=[DateTime]::UtcNow.ToString('o');before=$before;
    scope='Injected actual native MouseMove event bridge only. No OS/Web input, camera pixels, mobile or whole-game performance acceptance.'}
$manifestPath=Join-Path $evidence 'manifest.json'
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestPath -Encoding utf8
$report=Join-Path $evidence 'result.json';$metrics=Join-Path $evidence 'mouse-native.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=mobile','-validate',
    '-validate-frames=710','-validate-timeout=240','-validate-spike-threshold=100',
    ('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-mouse-delta-native.lua'),
    ('-mouse-golden='+$goldenPath),('-mouse-native-output='+$metrics))
$process=Start-Process -FilePath $runtime -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($evidence+'/stdout.txt') -RedirectStandardError ($evidence+'/stderr.txt')
$deadline=[DateTime]::UtcNow.AddSeconds(255)
while(-not $process.WaitForExit(500)){
    if([DateTime]::UtcNow -ge $deadline){$process.Kill();$process.WaitForExit();throw ('Native mouse verification timed out; evidence retained: '+$evidence)}
}
$manifest.after=Get-ProbeHashes;$manifest.finishedUtc=[DateTime]::UtcNow.ToString('o');$manifest.runtimeExit=$process.ExitCode
$manifest.changedDuringRun=@($files|Where-Object {$before[$_] -ne $manifest.after[$_]})
$manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Output $evidence
if($manifest.changedDuringRun.Count){throw 'Production or fixture changed during native run'}
if(-not(Test-Path -LiteralPath $report) -or -not(Test-Path -LiteralPath $metrics)){throw 'Native fixture produced incomplete evidence'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$details=Get-Content -LiteralPath $metrics -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
$details|Select-Object complete,checks,frames,scenarios,events,error,cleanupError|ConvertTo-Json -Depth 5
if(-not $details.complete -or $details.error){throw 'Native injected pointer assertions failed'}
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Native overall validation did not PASS; retain cold-start/render errors and the original 100 ms gate'}
