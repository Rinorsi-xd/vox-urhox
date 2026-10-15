$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskEntry=Join-Path $taskRoot 'scripts/_source_layer_lifetime_check.lua'
if(Test-Path -LiteralPath $taskEntry){throw 'Source layer fixture entry already exists'}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'entries/source-layer-lifetime.lua') -Destination $taskEntry
try {
    $taskArgs=@('_source_layer_lifetime_check.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate','-validate-frames=42','-validate-timeout=25','-validate-spike-threshold=100',('-validate-test='+$PSScriptRoot+'/check-source-layer-lifetime.lua'),('-validate-output='+$taskRoot+'/docs/migration/evidence/source-layer-lifetime-native.json'),'-log','info')
    $taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput ($taskRoot+'/.tmp/source-layer-lifetime-out.txt') -RedirectStandardError ($taskRoot+'/.tmp/source-layer-lifetime-err.txt')
    if(-not $taskProcess.WaitForExit(35000)){$taskProcess.Kill();throw 'Source layer lifetime timeout'}
    $taskResult=Get-Content ($taskRoot+'/docs/migration/evidence/source-layer-lifetime-native.json') -Raw | ConvertFrom-Json
    $taskResult|Select-Object result,test_result,test_assertions,summary|ConvertTo-Json -Depth 5
    if($taskResult.result -ne 'PASS' -or $taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'Source layer lifetime failed'}
} finally {
    Remove-Item -LiteralPath $taskEntry
    if(Test-Path -LiteralPath ($taskEntry+'.meta')){Remove-Item -LiteralPath ($taskEntry+'.meta')}
}
