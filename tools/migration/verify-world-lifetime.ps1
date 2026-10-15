$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskEntry=Join-Path $taskRoot 'scripts/_world_lifetime_check.lua'
if(Test-Path -LiteralPath $taskEntry){throw 'Lifetime fixture entry already exists'}
$taskStamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$taskOutput=Join-Path $taskRoot ('docs/migration/evidence/world-lifetime-'+$taskStamp)
New-Item -ItemType Directory -Path $taskOutput | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'entries/retained-post.lua') -Destination $taskEntry
try {
    $taskArgs=@('_world_lifetime_check.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate','-validate-frames=8','-validate-timeout=35','-validate-spike-threshold=100',('-validate-test='+$PSScriptRoot+'/check-world-lifetime.lua'),('-validate-output='+$taskOutput+'/result.json'),'-log','info')
    $taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput ($taskOutput+'/stdout.txt') -RedirectStandardError ($taskOutput+'/stderr.txt')
    if(-not $taskProcess.WaitForExit(45000)){$taskProcess.Kill();throw 'World lifetime timeout'}
    $taskResult=Get-Content ($taskOutput+'/result.json') -Raw | ConvertFrom-Json
    $taskResult|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 5
    Write-Output $taskOutput
    if($taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'World lifetime failed; preserved result distinguishes functionality from frame spikes'}
} finally {
    Remove-Item -LiteralPath $taskEntry
    if(Test-Path -LiteralPath ($taskEntry+'.meta')){Remove-Item -LiteralPath ($taskEntry+'.meta')}
}
