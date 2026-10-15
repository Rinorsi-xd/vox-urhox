param([ValidateSet('normal','car','hall','door','rear','display')][string]$View='normal',[switch]$Dev,[ValidateSet('desktop','mobile')][string]$Quality='desktop',[switch]$Trial,[switch]$Build,[switch]$Crater,
    [ValidateSet('HoverBottom','HoverSide','HeavyLift','LegT3','LegT5','LegWaveT5')][string]$Blueprint)
$ErrorActionPreference='Stop'
if((@($Trial,$Build,$Crater) | Where-Object {$_}).Count -gt 1){throw 'Choose only one entry: Trial, Build or Crater.'}
$runtime=Join-Path $PSScriptRoot '.cli/UrhoXRuntime.exe'
if (-not (Test-Path -LiteralPath $runtime)) { throw 'Install the project UrhoXRuntime in .cli first.' }
$runtimeArgs=@('main.lua',('-tapcode_dir='+$PSScriptRoot),'-tool_mode')
if ($View -ne 'normal') { $runtimeArgs+=('-hangar-view='+$View) }
if ($Dev) { $runtimeArgs+='-dev' }
if ($Trial) { $runtimeArgs+='-trial' }
if ($Crater) { $runtimeArgs+='-crater' }
if ($Build) { $runtimeArgs+='-build' }
if ($Blueprint) { $runtimeArgs+=('-blueprint=Blueprints/'+$Blueprint+'.json') }
$runtimeArgs+=('-quality='+$Quality)
Start-Process -FilePath $runtime -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -ArgumentList $runtimeArgs
