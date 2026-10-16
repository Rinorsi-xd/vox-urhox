param(
    [Parameter(Mandatory=$true)][string]$SnapshotRoot,
    [ValidateSet('none','coarse')][string]$Mode='none',
    [switch]$Coverage,
    [string]$ProjectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path,
    [string]$Runtime='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced/UrhoXRuntime.exe'
)
$ErrorActionPreference='Stop'
$SnapshotRoot=(Resolve-Path -LiteralPath $SnapshotRoot).Path
if ($SnapshotRoot -eq (Resolve-Path -LiteralPath $ProjectRoot).Path) { throw 'Use isolated snapshot, not production root' }
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'frozen-scripts.json') -Raw | ConvertFrom-Json
foreach ($entry in $manifest.PSObject.Properties) {
    $file=Join-Path $SnapshotRoot $entry.Name
    if (!(Test-Path -LiteralPath $file) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower() -ne $entry.Value) {
        throw ('Snapshot differs from measured source: '+$entry.Name)
    }
}
if (!(Test-Path -LiteralPath (Join-Path $SnapshotRoot 'assets'))) {
    New-Item -ItemType Junction -Path (Join-Path $SnapshotRoot 'assets') -Target (Join-Path $ProjectRoot 'assets') | Out-Null
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'NativeBattleCPU.lua') -Destination (Join-Path $SnapshotRoot 'scripts/NativeBattleCPU.lua')
$runRoot=Join-Path $ProjectRoot '.tmp/native-cpu-fa51051c-review'
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$name=if ($Coverage) { 'respawn-coverage' } else { $Mode }
$output=(Join-Path $runRoot ($name+'.json')).Replace('\','/')
$arguments=@('NativeBattleCPU.lua',('-tapcode_dir='+$SnapshotRoot),'-tool_mode','-skip_login','-skip_isolation','-log','info','-graphicsheadless','-quality=desktop','-pp',(Join-Path $ProjectRoot '.cli/'),('-cpu-output='+$output),('-cpu-mode='+$Mode))
if ($Coverage) { $arguments+='-cpu-coverage=true' }
$quoted=$arguments | ForEach-Object { '"'+$_.Replace('"','\"')+'"' }
$process=Start-Process -FilePath $Runtime -ArgumentList $quoted -WorkingDirectory $SnapshotRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runRoot ($name+'-stdout.txt')) -RedirectStandardError (Join-Path $runRoot ($name+'-stderr.txt'))
Write-Output ('OWN_RUNTIME_PID='+$process.Id)
if (!$process.WaitForExit(180000)) { $process.Kill();throw 'Own headless probe timed out' }
$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
if ($process.ExitCode -ne 0 -or $result.result -ne 'PASS') { throw ('Native probe failed: '+$result.error) }
Write-Output ('PASS '+$output)
