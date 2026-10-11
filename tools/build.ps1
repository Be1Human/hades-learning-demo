param(
    [string]$Godot=$env:GODOT_BIN,
    [string]$TemplateDir=$env:GODOT_TEMPLATES
)
$ErrorActionPreference='Stop'
$gameRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $gameRoot
if(!$Godot) {
    $command=Get-Command godot -ErrorAction SilentlyContinue
    if(!$command){throw 'Set GODOT_BIN or pass -Godot with a Godot 4.7.2 executable.'}
    $Godot=$command.Source
}
$Godot=(Resolve-Path -LiteralPath $Godot).Path
if(!$TemplateDir) {
    $TemplateDir=Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'
}
$templateFile=Join-Path $TemplateDir 'windows_release_x86_64.exe'
if(!(Test-Path -LiteralPath $templateFile)) {
    throw 'Install Godot 4.7.2 export templates, or pass -TemplateDir containing windows_release_x86_64.exe.'
}
$template=(Resolve-Path -LiteralPath $templateFile).Path.Replace('\','/')
$previousEnvironment=@{}
foreach($name in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) {
    $previousEnvironment[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
}
New-Item -ItemType Directory -Force 'build','build/cache','build/temp'|Out-Null
New-Item -ItemType File -Force 'build/.gdignore'|Out-Null
$env:APPDATA=Join-Path $gameRoot 'build/cache'
$env:LOCALAPPDATA=Join-Path $gameRoot 'build/cache'
$env:TEMP=Join-Path $gameRoot 'build/temp'
$env:TMP=$env:TEMP
$presets=Join-Path $gameRoot 'export_presets.cfg'
$original=[IO.File]::ReadAllText($presets)
try {
    [IO.File]::WriteAllText($presets,$original.Replace('custom_template/release=""',('custom_template/release="'+$template+'"')),[Text.UTF8Encoding]::new($false))
    $log=Join-Path $gameRoot 'build/export.log'
    $arguments=@('--headless','--editor','--path',('"'+$gameRoot+'"'),'--export-release','Windows',('"'+(Join-Path $gameRoot 'build/HadesDemo.exe')+'"'),'--log-file',('"'+$log+'"'))
    $process=Start-Process -FilePath $Godot -ArgumentList $arguments -WorkingDirectory $gameRoot -WindowStyle Hidden -PassThru -Wait
    if($process.ExitCode -ne 0){throw ('Godot export failed: '+$process.ExitCode)}
    if(Select-String -LiteralPath $log -Pattern '^ERROR:|^SCRIPT ERROR:' -Quiet){throw 'Godot reported an export error; read build/export.log.'}
    if(!(Test-Path -LiteralPath 'build/HadesDemo.exe') -or !(Test-Path -LiteralPath 'build/HadesDemo.pck')){throw 'Expected export files were not produced.'}
    Write-Output 'Exported build/HadesDemo.exe and build/HadesDemo.pck.'
} finally {
    [IO.File]::WriteAllText($presets,$original,[Text.UTF8Encoding]::new($false))
    foreach($name in $previousEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name,$previousEnvironment[$name],'Process')
    }
}
