$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $root
try {
    $report=$root+'/docs/migration/evidence/preview-cache.json'
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $args=@('main.lua',('-tapcode_dir='+$root),'-tool_mode','-quality=desktop','-validate','-validate-frames=230','-validate-timeout=70','-validate-spike-threshold=30000',('-validate-test='+$PSScriptRoot+'/check-preview-cache.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($root+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $root -WindowStyle Hidden -PassThru -ArgumentList $args -RedirectStandardOutput ($root+'/.tmp/preview-cache-out.txt') -RedirectStandardError ($root+'/.tmp/preview-cache-err.txt')
    if(-not $p.WaitForExit(80000)){$p.Kill();throw 'Preview cache verification timeout'}
    if(-not (Test-Path -LiteralPath $report)){throw "Preview runtime exited with code $($p.ExitCode) before producing a report"}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,test_issues | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Preview cache verification failed'}
} finally {Pop-Location}
