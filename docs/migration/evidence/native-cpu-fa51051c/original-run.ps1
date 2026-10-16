param([string]$Mode='fine',[switch]$Coverage)
$ErrorActionPreference = 'Stop'
$projectRoot = 'D:/Rino_Project/maker/Vox/VoxelCraft'
$runRoot = Join-Path $projectRoot '.tmp/headless-cpu-fa51051c'
$snapshotRoot = Join-Path $runRoot 'snapshot'
New-Item -ItemType Directory -Path $snapshotRoot -Force | Out-Null
if (!(Test-Path -LiteralPath (Join-Path $snapshotRoot 'scripts'))) {
    Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts') -Destination $snapshotRoot -Recurse
    Copy-Item -LiteralPath (Join-Path $projectRoot '.project') -Destination $snapshotRoot -Recurse
}
if (!(Test-Path -LiteralPath (Join-Path $snapshotRoot 'assets'))) {
    New-Item -ItemType Junction -Path (Join-Path $snapshotRoot 'assets') -Target (Join-Path $projectRoot 'assets') | Out-Null
}
Copy-Item -LiteralPath (Join-Path $runRoot 'NativeBattleCPU.lua') -Destination (Join-Path $snapshotRoot 'scripts/NativeBattleCPU.lua')
if (!(Test-Path -LiteralPath (Join-Path $runRoot 'frozen-scripts.json'))) {
    $hashes = [ordered]@{}
    Get-ChildItem -LiteralPath (Join-Path $snapshotRoot 'scripts') -Filter '*.lua' -Recurse | Where-Object { $_.Name -ne 'NativeBattleCPU.lua' } | Sort-Object FullName | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($snapshotRoot, $_.FullName).Replace('\','/')
        $hashes[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower()
    }
    $hashes | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $runRoot 'frozen-scripts.json') -Encoding utf8
}
$runtime = 'D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
$runName = if ($Coverage) { 'respawn-coverage' } else { $Mode }
$result = (Join-Path $runRoot ($runName + '.json')).Replace('\','/')
$arguments = @('NativeBattleCPU.lua', ('-tapcode_dir=' + $snapshotRoot), '-tool_mode', '-skip_login', '-skip_isolation', '-log', 'info', '-graphicsheadless', '-quality=desktop', '-pp', (Join-Path $projectRoot '.cli/'), ('-cpu-output=' + $result), ('-cpu-mode=' + $Mode))
if ($Coverage) { $arguments += '-cpu-coverage=true' }
$quoted = $arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }
$process = Start-Process -FilePath $runtime -ArgumentList $quoted -WorkingDirectory $snapshotRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runRoot ($runName + '-stdout.txt')) -RedirectStandardError (Join-Path $runRoot ($runName + '-stderr.txt'))
Write-Output ('OWN_RUNTIME_PID=' + $process.Id)
if (!$process.WaitForExit(180000)) { $process.Kill(); throw 'Own headless probe timed out' }
Write-Output ('EXIT=' + $process.ExitCode)
Get-Content -LiteralPath $result -Raw | ConvertFrom-Json | Select-Object result,error,simulationSeconds,measuredSteps,warmupSteps,stages | ConvertTo-Json -Depth 4
