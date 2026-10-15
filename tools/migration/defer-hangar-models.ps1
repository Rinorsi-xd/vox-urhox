# Mechanical resource migration. Preserve UMDL bytes and resource identities.
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$assets=Join-Path $projectRoot 'assets'
$modelDir=Join-Path $assets 'Hangar/Models'
$reportPath=Join-Path $projectRoot 'docs/migration/evidence/hangar-deferred-models.json'
$models=@(Get-ChildItem -LiteralPath $modelDir -Filter '*.mdl' | Sort-Object Name)
if(-not $models.Count){
    $previous=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $totalBytes=0L
    foreach($record in $previous.models){
        $totalBytes+=$record.bytes
        $target=Join-Path $assets $record.target
        if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $record.sha256){throw "Changed model: $target"}
        $meta=Get-Content -LiteralPath ($target+'.meta') -Raw | ConvertFrom-Json
        if($meta.uuid -ne $record.uuid){throw "Changed identity: $target"}
    }
    if($previous.bytes -ne $totalBytes){
        $previous.bytes=$totalBytes
        [IO.File]::WriteAllText($reportPath,($previous|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
    }
    @{verified=$true;models=$previous.models.Count;bytes=$previous.bytes}|ConvertTo-Json -Compress
    exit
}
$records=@(foreach($model in $models){
    $source='Hangar/Models/'+$model.Name
    $target=$source.Substring(0,$source.Length-4)+'.bin'
    $bytes=[IO.File]::ReadAllBytes($model.FullName)
    if([Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'UMDL'){throw "Unexpected format: $source"}
    if((Test-Path -LiteralPath (Join-Path $assets $target)) -or (Test-Path -LiteralPath (Join-Path $assets ($target+'.meta')))){throw "Destination exists: $target"}
    $meta=Get-Content -LiteralPath ($model.FullName+'.meta') -Raw | ConvertFrom-Json
    if(-not $meta.uuid){throw "Missing identity: $source"}
    [ordered]@{source=$source;target=$target;sha256=(Get-FileHash -LiteralPath $model.FullName -Algorithm SHA256).Hash.ToLowerInvariant();bytes=$bytes.Length;uuid=$meta.uuid}
})
$replacements=@{}
foreach($record in $records){$replacements[$record.source]=$record.target}
$scenePath=Join-Path $assets 'Scenes/OrbitalHangar.xml'
$scene=[Xml.XmlDocument]::new()
$scene.PreserveWhitespace=$true
$scene.Load($scenePath)
$used=@{}
foreach($attribute in $scene.SelectNodes('//attribute[@name="Model"]')){
    $value=$attribute.GetAttribute('value')
    if($value.StartsWith('Model;')){
        $modelPath=$value.Substring(6)
        if($replacements.ContainsKey($modelPath)){
            $attribute.SetAttribute('value','Model;'+$replacements[$modelPath])
            $used[$modelPath]=$true
        }elseif($modelPath.StartsWith('Hangar/Models/')){throw "Unknown hall model: $modelPath"}
    }
}
if($used.Count -ne $records.Count){throw 'Some hall models are absent from the authored scene; inspect before migrating.'}
foreach($record in $records){
    Move-Item -LiteralPath (Join-Path $assets $record.source) -Destination (Join-Path $assets $record.target)
    Move-Item -LiteralPath (Join-Path $assets ($record.source+'.meta')) -Destination (Join-Path $assets ($record.target+'.meta'))
}
$scene.Save($scenePath)
$utf8=[Text.UTF8Encoding]::new($false)
$resources=@('Scenes/OrbitalHangar.xml')+@($records|ForEach-Object {$_.target})
[IO.File]::WriteAllText((Join-Path $assets 'Hangar/Resources.json'),(ConvertTo-Json -InputObject $resources),$utf8)
$totalBytes=0L
foreach($record in $records){$totalBytes+=$record.bytes}
$report=[ordered]@{migratedAt=[DateTime]::UtcNow.ToString('o');format='UMDL';extension='.bin';bytes=$totalBytes;models=$records}
[IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 5),$utf8)
@{migrated=$true;models=$records.Count;bytes=$report.bytes}|ConvertTo-Json -Compress
