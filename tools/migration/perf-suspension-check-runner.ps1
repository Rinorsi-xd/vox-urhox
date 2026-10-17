$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$source=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'perf-suspension-run.ps1') -Raw
$parseErrors=$null
[System.Management.Automation.Language.Parser]::ParseInput($source,[ref]$null,[ref]$parseErrors) | Out-Null
if($parseErrors.Count){throw ($parseErrors|Out-String)}
$start=$source.IndexOf(' if(!$probe.WaitForExit(90000))')
$end=$source.IndexOf(' $result.scenarios|',$start)
if($start -lt 0 -or $end -lt 0){throw 'Cannot find actual runner completion/identity block.'}
$completion=[scriptblock]::Create($source.Substring($start,$end-$start))
$probeRoot=Join-Path $projectRoot ('.tmp/perf-suspension-runner-fixture-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $probeRoot | Out-Null
$label='baseline-1';$mode='baseline';$runIdentity=@{seed=16102026}
$runtimeVersion='0.9.0-beta.40_20261015.121839.6dc5c357cced';$arguments=@('-probe-mode=baseline')
$raw=Get-Content -LiteralPath (Join-Path $projectRoot 'docs/migration/evidence/perf-suspension-2026-10-16/baseline-1.json') -Raw
$output=Join-Path $probeRoot 'baseline-1.json'
$checks=0
foreach($test in @(@{exit=$null;wait=$true;fail=$false},@{exit=0;wait=$true;fail=$false},@{exit=7;wait=$true;fail=$true},@{exit=0;wait=$false;fail=$true})){
 $raw | Set-Content -LiteralPath $output -Encoding utf8
 $probe=[pscustomobject]@{Id=-1;ExitCode=$test.exit;completed=$test.wait;killed=$false}
 $probe | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {param($timeout) return $this.completed}
 $probe | Add-Member -MemberType ScriptMethod -Name Refresh -Value {}
 $probe | Add-Member -MemberType ScriptMethod -Name Kill -Value {$this.killed=$true}
 $failed=$false
 try{& $completion}catch{$failed=$true}
 if($failed -ne $test.fail){throw 'Runner completion fixture unexpected result.'}
 if(!$failed){
  $record=Get-Content -LiteralPath (Join-Path $probeRoot 'baseline-1.process.json') -Raw | ConvertFrom-Json
  if(!$record.waitForExitCompleted -or $record.exitCodeAvailable -ne ($null -ne $test.exit)){throw 'Runner completion evidence mismatch.'}
 }
 $checks++
}
Write-Output ('RUNNER_FIXTURES_PASS='+$checks+' (mock Process only; no Runtime started)')
