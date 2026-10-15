$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$stamp=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss-fffZ')
$evidence=Join-Path $projectRoot ('docs/migration/evidence/audio-settings-'+$stamp)
New-Item -ItemType Directory -Path $evidence | Out-Null
$report=Join-Path $evidence 'result.json'
$runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate','-validate-frames=1100','-validate-timeout=150',
    '-validate-spike-threshold=100',('-validate-output='+$report),'-log','info',('-audio-ui-out='+$evidence.Replace('\','/')),
    ('-validate-test='+$PSScriptRoot+'/check-audio-settings.lua'))
$process=Start-Process -FilePath ($projectRoot+'/.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($evidence+'/stdout.txt') -RedirectStandardError ($evidence+'/stderr.txt')
if(-not $process.WaitForExit(165000)){$process.Kill();throw 'Audio settings verification timeout'}
$result=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$result|Select-Object result,test_result,test_assertions,summary,test_issues|ConvertTo-Json -Depth 6
Write-Output ('Evidence: '+$evidence)
if($result.test_result -ne 'PASSED' -or $result.summary.total_errors -ne 0){throw 'Audio settings functionality failed'}
if($result.result -ne 'PASS'){Write-Warning 'Audio functionality passed but performance remains failed; report preserves measured spikes'}
