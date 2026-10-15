param([int]$Width=1280,[int]$Height=720)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskEntry=Join-Path $taskRoot 'scripts/_safe_reset_check.lua'
if(Test-Path -LiteralPath $taskEntry){throw 'Safe reset fixture entry already exists'}
$taskStamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$taskOutput=Join-Path $taskRoot ('docs/migration/evidence/safe-reset-'+$taskStamp)
New-Item -ItemType Directory -Path $taskOutput | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'entries/retained-post.lua') -Destination $taskEntry
try {
$taskArgs=@('_safe_reset_check.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate','-validate-frames=16','-validate-timeout=45','-validate-spike-threshold=100',('-validate-test='+$PSScriptRoot+'/check-safe-reset.lua'),('-validate-output='+$taskOutput+'/result.json'),('-reset-out='+$taskOutput),'-x',$Width,'-y',$Height,'-log','info')
$taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput ($taskOutput+'/stdout.txt') -RedirectStandardError ($taskOutput+'/stderr.txt')
if(-not $taskProcess.WaitForExit(55000)){$taskProcess.Kill();throw 'Safe reset verification timeout'}
$taskResult=Get-Content ($taskOutput+'/result.json') -Raw | ConvertFrom-Json
$taskResult|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
Write-Output $taskOutput
if($taskResult.result -ne 'PASS' -or $taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'Safe reset verification failed; preserve functional and 100ms performance evidence separately'}
} finally {
    Remove-Item -LiteralPath $taskEntry
    if(Test-Path -LiteralPath ($taskEntry+'.meta')){Remove-Item -LiteralPath ($taskEntry+'.meta')}
}
