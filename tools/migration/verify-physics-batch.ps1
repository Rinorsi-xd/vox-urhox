$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectRoot
try {node tools/migration/source-camera-feedback.mjs;if($LASTEXITCODE -ne 0){throw 'Camera source fixture failed'}} finally {Pop-Location}
Push-Location $projectRoot
try {node tools/migration/source-damage-credit.mjs;if($LASTEXITCODE -ne 0){throw 'Damage attribution fixture failed'}} finally {Pop-Location}
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/physics-batch-'+$stamp)
New-Item -ItemType Directory -Path $evidence | Out-Null
$report=Join-Path $evidence 'result.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=200','-validate-timeout=110','-validate-spike-threshold=30000',('-validate-output='+$report),'-log','info',('-validate-test='+$PSScriptRoot+'/check-physics-batch.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($evidence+'/stdout.txt') -RedirectStandardError ($evidence+'/stderr.txt')
if(-not $process.WaitForExit(120000)){$process.Kill();throw 'Physics batch verification timeout'}
$result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
Write-Output $evidence
if($result.result -ne 'PASS' -or $result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Physics batch verification failed'}
