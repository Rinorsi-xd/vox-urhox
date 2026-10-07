$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scenePath=Join-Path $projectRoot 'assets/Scenes/OrbitalHangar.xml'
$validFixture=Join-Path $projectRoot 'assets/Scenes/HangarLifecycleFixture.xml'
$invalidFixture=Join-Path $projectRoot 'assets/Scenes/HangarInvalidFixture.xml'
if ((Test-Path -LiteralPath $validFixture) -or (Test-Path -LiteralPath $invalidFixture)) { throw 'Fixture paths already exist.' }
try {
    [xml]$scene=Get-Content -LiteralPath $scenePath -Raw
    $equipment=$scene.SelectSingleNode('//node[attribute[@name="Name" and @value="Equipment"]]/attribute[@name="Position"]')
    $equipment.SetAttribute('value','1.25 0 0')
    $scene.Save($validFixture)
    $root=$scene.SelectSingleNode('//node/attribute[@name="Name" and @value="OrbitalHangar"]')
    $root.SetAttribute('value','InvalidFixture')
    $scene.Save($invalidFixture)
    $report=Join-Path $projectRoot 'docs/migration/evidence/lifecycle.json'
    $runtimeArgs=@('main.lua',('-tapcode_dir='+$projectRoot),'-tool_mode','-validate',
        '-validate-frames=330','-validate-timeout=90','-validate-spike-threshold=500',
        ('-validate-test='+$PSScriptRoot+'/check-lifecycle.lua'),('-validate-output='+$report),'-log','info')
    $p=Start-Process -FilePath (Join-Path $projectRoot '.cli/UrhoXRuntime.exe') -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -ArgumentList $runtimeArgs -RedirectStandardOutput ($projectRoot+'/.tmp/lifecycle-out.txt') -RedirectStandardError ($projectRoot+'/.tmp/lifecycle-err.txt')
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while (-not $p.WaitForExit(1000)) { if ($timer.Elapsed.TotalSeconds -gt 110) { $p.Kill();throw 'Lifecycle validation timed out' } }
    $result=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $result | Select-Object result,test_result,test_assertions,summary,missing_resources | ConvertTo-Json -Depth 5
    if ($result.result -ne 'PASS') { throw 'Lifecycle validation failed' }
} finally {
    # Only the two explicit files created above; no recursive removal or computed directories.
    Remove-Item -LiteralPath $validFixture,$invalidFixture -ErrorAction SilentlyContinue
}
