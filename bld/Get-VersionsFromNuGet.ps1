param(
    [Switch]$Download,
    [Switch]$OnlyNew
)

$ErrorActionPreference = "STOP"

$folder = Join-Path $PSScriptRoot "../packages"

$versions = & nuget list Sitecore  -AllVersions -NonInteractive -Source https://sitecore.myget.org/F/sc-packages/api/v3/index.json
$versions = $versions | Where-Object { $_ -like "Sitecore *" } | ForEach-Object { ($_ -split " ")[1] }

if($OnlyNew) {
    $versions = $versions | ForEach-Object {
        $version = $_
        $path = Join-Path $folder "Sitecore.${version}"
        if(-not (Test-Path $path)) {
            $version
        }
    }
}

Write-Host "Versions:"
$versions | Format-Table

if($Download) {
    $versions | ForEach-Object {
        & nuget install Sitecore -Version $_ -NonInteractive -OutputDirectory $folder -Source https://sitecore.myget.org/F/sc-packages/api/v3/index.json
    }    
}