param(
    [Parameter(Mandatory=$true)][string]$Runtime,
    [string]$EngineResources,
    [switch]$RenderedBattle
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$evidenceRoot = Join-Path $projectRoot 'docs/migration/evidence/perf-1016'
$runRoot = Join-Path $projectRoot ('.tmp/perf-1016-' + [guid]::NewGuid().ToString('N'))
$snapshotRoot = Join-Path $runRoot 'snapshot'
if (!(Test-Path -LiteralPath $Runtime -PathType Leaf)) { throw 'Runtime executable missing.' }
New-Item -ItemType Directory -Path $snapshotRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts') -Destination $snapshotRoot -Recurse
Copy-Item -LiteralPath (Join-Path $projectRoot '.project') -Destination $snapshotRoot -Recurse
New-Item -ItemType Junction -Path (Join-Path $snapshotRoot 'assets') -Target (Join-Path $projectRoot 'assets') | Out-Null
Copy-Item -LiteralPath (Join-Path $evidenceRoot 'before') -Destination $runRoot -Recurse
$jobs = @(
    @{entry='PerfOptimizationProbe.lua'; result='probe-result.json'},
    @{entry='PerfExtendedProbe.lua'; result='extended-result.json'},
    @{entry='PerfRangesProbe.lua'; result='ranges-result.json'}
)
if ($RenderedBattle) { $jobs += @{entry='perf-profile.lua'; result='mobile-profile-native.json'; rendered=$true} }
$utf8 = [System.Text.UTF8Encoding]::new($false)
foreach ($job in $jobs) {
    $source = [IO.File]::ReadAllText((Join-Path $evidenceRoot $job.entry))
    # Adapt the archived measurement path only in the isolated probe copy.
    $source = $source.Replace('D:/Rino_Project/maker/Vox/VoxelCraft/.tmp/perf-optimization-20261016/', ($runRoot.Replace('\','/') + '/'))
    [IO.File]::WriteAllText((Join-Path $snapshotRoot ('scripts/' + $job.entry)), $source, $utf8)
    $resultPath = Join-Path $runRoot $job.result
    $arguments = @($job.entry, ('-tapcode_dir=' + $snapshotRoot), '-tool_mode', '-skip_login', '-skip_isolation', '-log', 'info')
    if ($EngineResources) { $arguments += @('-pp', $EngineResources) }
    if ($job.rendered) {
        $arguments += @('-quality=mobile', '-profile-mode=none', '-profile-scenario=engagement', ('-profile-output=' + $resultPath.Replace('\','/')))
    } else { $arguments += @('-graphicsheadless', '-quality=desktop') }
    # Quote arguments for Start-Process, including workspaces containing spaces.
    $quoted = $arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }
    $process = Start-Process -FilePath $Runtime -ArgumentList $quoted -WorkingDirectory $snapshotRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runRoot ($job.entry + '.out.txt')) -RedirectStandardError (Join-Path $runRoot ($job.entry + '.err.txt'))
    if (!$process.WaitForExit(300000)) { $process.Kill(); throw ('Own probe timed out: ' + $job.entry) }
    if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $resultPath)) { throw ('Probe failed: ' + $job.entry + '; logs: ' + $runRoot) }
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if ($result.result -ne 'PASS') { throw ('Probe assertion failure: ' + $job.entry + '; ' + $result.message) }
    Write-Output ($job.entry + ': PASS; result=' + $resultPath)
}
Write-Output ('Evidence retained: ' + $runRoot)
Write-Output 'PASS means probe completion/equivalence. It does not mean sustained 30 FPS, Web, or Snapdragon 845 acceptance.'
