param(
    [Switch]
    $Commit,

    [array]$Versions = $Null, 
    [array]$MajorVersions = $Null
)

$ErrorActionPreference = "STOP"

$packagesFolder = Join-Path $PSScriptRoot "../packages" -Resolve
$targetDir = Join-Path (Join-Path $PSScriptRoot ".." -Resolve) "Sitecore\Sitecore Decompiled"

$decompiler = Join-Path ${env:ProgramFiles(x86)} "Telerik\JustDecompile\Libraries\JustDecompile.exe" -Resolve

if($Versions -eq $null) {
    Write-Host "Reading available versions from $packagesFolder..."

    $folders = Get-ChildItem -Path $packagesFolder -Filter "Sitecore.*"  | Select-Object -ExpandProperty Name
    $Versions = $folders | Where-Object {
        $folder = $_
        $include = $folder -match "^Sitecore\.\d+\.\d+\.\d+$"
        return $include
    } | ForEach-Object {
        return $_.Substring("Sitecore.".Length)
    }
}

$invalidVersions = $Versions | Where-Object {
    $version = $_
    $expectedPath = Join-Path $packagesFolder "Sitecore.${version}"
    return -not (Test-Path $expectedPath)
}
if($invalidVersions.length -gt 0) {
    Write-Error ("Versions doesn't exists (maybe you need to get it first): {0}" -f ($invalidVersions -join ", "))
}

if($MajorVersions -ne $null -and $MajorVersions.length -gt 0) {
    $Versions = $Versions | Where-Object { 
        $version = $_
        $current = $version.Split(".")[0]
        $include = $MajorVersions.Contains([int]$current)
        return $include
    }
}

Write-Host
Write-Host "Versions to process:"
$Versions | Format-Table
Write-Host

Add-Type -Assembly System.IO.Compression.FileSystem

$Versions | ForEach-Object {
    $version = $_
    $major = $version.Split(".")[0]

    # Switch to branch
    $branchname = "v${major}"
    & git branch $branchname
    & git checkout $branchname

    # Extract nuspec
    $pkgFile = (Join-Path $packagesFolder "Sitecore.${version}\Sitecore.${version}.nupkg" -Resolve)
    $specFile = (Join-Path $packagesFolder "Sitecore.${version}\Sitecore.nuspec")

    If(-not (Test-Path $specFile)) {
        $zip = [IO.Compression.ZipFile]::OpenRead($pkgFile)
        $pkgEntry = $zip.Entries | Where-Object { $_.FullName -eq "Sitecore.nuspec" } | Select-Object -First 1
        if($pkgEntry -eq $null) {
            Write-Error "Cannot find Sitecore.nuspec in $pkgFile"
        }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($pkgEntry, $specFile)
        $zip.Dispose()
    }

    # Find dependencies
    $spec = [xml](Get-Content -Path $specFile)
    $packages = ,@([PSCustomObject]@{id="Sitecore";version=$version})
    $spec.package.metadata.dependencies.group.dependency | ForEach-Object {
        $id = $_.id
        $version = $_.version  -replace "[\[\]]", ""
        #Write-Host "id: $id version: $version"
        $packages += [PSCustomObject]@{id=$id;version=$version}
    }

    # Find assemblies
    $assemblies = @()
    $packages | ForEach-Object {
        $path = Join-Path $packagesFolder ("{0}.{1}\lib" -f $_.id, $_.version)
        Get-ChildItem -Path $path -Recurse -Filter "*.dll" | ForEach-Object {
            $assemblies += $_.FullName
        }
    }

    # Clean output
    Get-ChildItem $targetDir | ForEach-Object {
        If($_ -ne "README.md") {
            Remove-Item -Path $_ -Force -Recurse | Out-Null
        }
    }

    # Decompile
    $assemblies | ForEach-Object {
        $name = (Split-Path $_ -Leaf).Replace(".dll", "")
        Write-Host "Decompiling $name..."
        & $decompiler /lang:csharp /out:${targetDir}\${name} /target:$_
    }

    # Commit
    & git add -A
    & git commit -m "Added version $version"
    $tag = "v${version}"
    & git tag -a $tag
}