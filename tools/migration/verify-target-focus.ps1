$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
node (Join-Path $PSScriptRoot 'source-target-focus.mjs')
if($LASTEXITCODE -ne 0){throw 'Frozen focus source failed'}
$taskEntry=Join-Path $taskRoot 'scripts/_target_focus_check.lua'
if(Test-Path -LiteralPath $taskEntry){throw 'Target focus fixture already exists'}
$taskOutput=Join-Path $taskRoot ('docs/migration/evidence/target-focus-'+[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ'))
New-Item -ItemType Directory -Path $taskOutput | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'entries/retained-post.lua') -Destination $taskEntry
try {
    $taskArgs=@('_target_focus_check.lua',('-tapcode_dir='+$taskRoot),'-tool_mode','-validate','-validate-frames=18','-validate-timeout=45','-validate-spike-threshold=100',('-validate-test='+$PSScriptRoot+'/check-target-focus.lua'),('-validate-output='+$taskOutput+'/result.json'),'-log','info')
    $taskProcess=Start-Process -FilePath ($taskRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -ArgumentList $taskArgs -RedirectStandardOutput ($taskOutput+'/stdout.txt') -RedirectStandardError ($taskOutput+'/stderr.txt')
    if(-not $taskProcess.WaitForExit(55000)){$taskProcess.Kill();throw 'Target focus verification timeout'}
    Copy-Item -Path (Join-Path $taskRoot 'docs/migration/evidence/target-focus-*.png') -Destination $taskOutput -ErrorAction SilentlyContinue
    $taskResult=Get-Content ($taskOutput+'/result.json') -Raw | ConvertFrom-Json
    $taskResult|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
    Write-Output $taskOutput
    if($taskResult.result -ne 'PASS' -or $taskResult.test_result -ne 'PASSED' -or $taskResult.summary.total_errors -ne 0){throw 'Target focus verification failed; preserve report'}
} finally {
    Remove-Item -LiteralPath $taskEntry
    if(Test-Path -LiteralPath ($taskEntry+'.meta')){Remove-Item -LiteralPath ($taskEntry+'.meta')}
}
