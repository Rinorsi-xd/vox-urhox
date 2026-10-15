param([string]$Test='check-minimap-render.lua',[int]$Frames=25)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff')
$report=$root+'/docs/migration/evidence/minimap-render-'+$stamp+'.json'
$runtimeArgs=@('_minimap_check.lua',('-tapcode_dir='+$root),'-tool_mode','-quality=desktop','-validate',('-validate-frames='+$Frames),'-validate-timeout=40','-validate-spike-threshold=100',('-validate-test='+$PSScriptRoot+'/'+$Test),('-validate-output='+$report),'-log','info')
$p=Start-Process -FilePath ($root+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $root -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($root+'/.tmp/minimap-render-'+$stamp+'-out.txt') -RedirectStandardError ($root+'/.tmp/minimap-render-'+$stamp+'-err.txt')
$timer=[Diagnostics.Stopwatch]::StartNew()
while(-not $p.WaitForExit(500)){if($timer.Elapsed.TotalSeconds -gt 50){$p.Kill();throw 'Minimap verification timeout'}}
Get-Content -LiteralPath $report -Raw
Get-Content -LiteralPath ($root+'/.tmp/minimap-render-'+$stamp+'-out.txt') -Tail 30
