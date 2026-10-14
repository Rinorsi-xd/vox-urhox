$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {
    $evidence=$projectRoot+'/docs/migration/evidence/window-viewports-'+[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
    New-Item -ItemType Directory -Path $evidence | Out-Null
    $report=$evidence+'/report.json'
    # This checks viewport ownership, not cold-start frame pacing (measured separately).
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-quality=desktop','-validate','-validate-frames=70','-validate-timeout=90','-validate-spike-threshold=2000',('-validate-test='+$PSScriptRoot+'/check-window-viewports.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($evidence+'/stdout.log') -RedirectStandardError ($evidence+'/stderr.log')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 105){$p.Kill();throw 'Window viewport verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,missing_resources,test_issues | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0 -or $r.test_assertions.total -lt 15){throw 'Window viewport verification failed'}
    Write-Output $evidence
} finally {Pop-Location}
