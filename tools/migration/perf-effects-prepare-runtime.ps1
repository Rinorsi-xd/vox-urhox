param([string]$Destination='.tmp/perf-effects-runtime-beta40')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$source='D:/UrhoXEditor/versions/0.9.0-beta.40_20261015.121839.6dc5c357cced'
$target=[IO.Path]::GetFullPath((Join-Path $projectRoot $Destination))
$allowed=[IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp'))+[IO.Path]::DirectorySeparatorChar
if(!$target.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Runtime copy must be under workspace .tmp.'}
New-Item -ItemType Directory -Path $target -Force | Out-Null
$files=@('UrhoXRuntime.exe','OfflineShaderCompiler.exe','urhox-editor-build.json')+@(Get-ChildItem -LiteralPath $source -File -Filter '*.dll' | Select-Object -ExpandProperty Name)
$identity=@{}
foreach($name in $files){
 $from=Join-Path $source $name;$to=Join-Path $target $name
 $hash=(Get-FileHash -LiteralPath $from -Algorithm SHA256).Hash.ToLower()
 if(Test-Path -LiteralPath $to){if((Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash.ToLower() -ne $hash){throw ('Existing copy differs: '+$name)}}
 else{Copy-Item -LiteralPath $from -Destination $to}
 if((Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash.ToLower() -ne $hash){throw ('Copy hash differs: '+$name)}
 $identity[$name]=@{sha256=$hash;bytes=(Get-Item -LiteralPath $to).Length}
}
foreach($name in @('ResCache','ResCache/Shaders','ResCache/Shaders/BLGL','ResCache/Shaders/BLGL/Generated','ResCache/Shaders/BLGL/Generated/Surface','ResCache/shadercache_runtime')){New-Item -ItemType Directory -Path (Join-Path $target $name) -Force | Out-Null}
foreach($name in @('Res','CoreData','Data')){
 $link=Join-Path $target $name
 if(!(Test-Path -LiteralPath $link)){New-Item -ItemType Junction -Path $link -Target (Join-Path $source $name) | Out-Null}
}
$resources=@{}
foreach($entry in Get-ChildItem -LiteralPath (Join-Path $projectRoot '.cli/Autoload') -File -Filter '*.pak'){$resources[$entry.Name]=@{sha256=(Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash.ToLower();bytes=$entry.Length}}
$result=@{status='PREPARED_NOT_STARTED';source=$source;target=$target;files=$identity;resourcePrefix=$target;resourceDirectories=@('Res','CoreData','Data');legacyResourcePackages=$resources;boundary='Exact source executable and DLL hashes. Generated shader writes are confined to writable copied Runtime ResCache. Resource directories are read-only junctions to the same installed beta40 package, replacing older workspace .cli packages. No Runtime launched.'}
$result | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $target 'copy-identity.json') -Encoding utf8
$result | ConvertTo-Json -Depth 7
