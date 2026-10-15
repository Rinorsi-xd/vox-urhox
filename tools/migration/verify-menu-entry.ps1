$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$entry=Join-Path $root 'scripts/_menu_entry_check.lua'
if(Test-Path -LiteralPath $entry){throw 'Temporary menu entry already exists'}
[IO.File]::WriteAllText($entry, 'function Start() end', [Text.UTF8Encoding]::new($false))
Push-Location $root
try {
    $report=$root+'/docs/migration/evidence/pc-menu-entry-check.json'
    if(Test-Path -LiteralPath $report){Remove-Item -LiteralPath $report}
    $args=@('_menu_entry_check.lua',('-tapcode_dir='+$root),'-tool_mode','-quality=desktop','-validate','-validate-frames=100','-validate-timeout=40','-validate-spike-threshold=30000',('-validate-test='+$PSScriptRoot+'/check-menu-entry.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath ($root+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $root -WindowStyle Hidden -PassThru -ArgumentList $args -RedirectStandardOutput ($root+'/.tmp/menu-entry-out.txt') -RedirectStandardError ($root+'/.tmp/menu-entry-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 50){$p.Kill();throw 'Menu entry verification timeout'}}
    $r=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $r | Select-Object result,test_result,test_assertions,summary,test_issues | ConvertTo-Json -Depth 5
    if($r.result -ne 'PASS' -or $r.test_result -ne 'PASSED' -or $r.summary.total_errors -ne 0){throw 'Menu entry verification failed'}
} finally {
    Pop-Location;Remove-Item -LiteralPath $entry
    if(Test-Path -LiteralPath ($entry+'.meta')){Remove-Item -LiteralPath ($entry+'.meta')}
}
