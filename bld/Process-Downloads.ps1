param(
    [Switch]
    $Commit,

    [Switch]
    $OnlyNew,

    [array]$Versions = $Null, 
    [array]$MajorVersions = $Null
)

$targetDir = Join-Path (Join-Path $PSScriptRoot ".." -Resolve) "Sitecore"
$decompiler = Join-Path ${env:ProgramFiles(x86)} "Telerik\JustDecompile\Libraries\JustDecompile.exe" -Resolve

Add-Type -Assembly System.IO.Compression.FileSystem

$files = Get-ChildItem "${PSScriptRoot}\..\downloads" -Filter *.zip | Select-Object -ExpandProperty FullName

if($MajorVersions -ne $null -and $MajorVersions.length -gt 0) {
    $files = $files | Where-Object { 
        $name = (Split-Path $_ -Leaf).Replace(".zip", "")
        $verName = $name.Substring("Sitecore ".Length)
        $version = $verName.Replace(" rev. ", ".")
        $current = $version.Split(".")[0]
        $include = $MajorVersions.Contains([int]$current)
        return $include
    }
}

if($Versions -ne $null -and $Versions.length -gt 0) {
    $files = $files | Where-Object { 
        $name = (Split-Path $_ -Leaf).Replace(".zip", "")
        $verName = $name.Substring("Sitecore ".Length)
        $version = $verName.Replace(" rev. ", ".")
        $include = $Versions.Contains($version)
        return $include
    }
}

if($OnlyNew) {
    $tags = & git tag --list
    $files = $files | Where-Object {
        $name = (Split-Path $_ -Leaf).Replace(".zip", "")
        $verName = $name.Substring("Sitecore ".Length)
        $version = $verName.Replace(" rev. ", ".")
        $tag = "v{$version}"
        $include = $tags.Contains($tag)
        return $include
    }
}

$files | ForEach-Object {
    $name = (Split-Path $_ -Leaf).Replace(".zip", "")
    $verName = $name.Substring("Sitecore ".Length)
    $revName = $name.Substring($name.IndexOf("rev. "))
    $zip = [IO.Compression.ZipFile]::OpenRead($_)

    $version = $verName.Replace(" rev. ", ".")
    $major = $version.Split(".")[0]
    $tag = "v{$version}"

    Write-Output "verName: '$verName'"
    Write-Output "revName: '$revName'"
    Write-Output "version: '$version'"
    Write-Output "major: '$version'"

    # Switch to branch
    if($Commit) {
        $branchname = "v${major}"
        & git branch $branchname
        & git checkout $branchname
    }

    # Clean output
    Get-ChildItem $targetDir | ForEach-Object {
        If($_.Name -ne "README.md") {
            Remove-Item -Path $_.FullName -Force -Recurse | Out-Null
        }
    }

    # Create hashmap with all files
    $entries = @{}
    $zip.Entries | ForEach-Object {
        $path = $_.FullName
        $entries.$path = "1"
    }

    Write-Output "Extracting files from $name..."
    $zip.Entries | ForEach-Object {
        $entry = $_
        $entryPath = $_.FullName
        $name = Split-Path $entryPath -Leaf

        # Files to ignore
        $ignore = $entryPath -like "*.dacpac" -or $entryPath -like "*.lic" -or `
                  $entryPath -like "*.mdf" -or $entryPath -like "*.ldf" -or `
                  $entryPath -like "*.log" -or `
                  $entryPath -like "*/indexes/*" -or $entryPath -like "*/phantomjs/*" -or `
                  $entryPath -like "*/submitqueue"
        if($ignore) {
            Return
        }

        # Ignore xml description file of assemblies
        if($entryPath -like "*.xml") {
            $key1 = $entryPath.Replace(".xml", ".dll")
            $key2 = $entryPath.Replace(".xml", ".exe")
            if($entries.$key1 -eq "1" -or $entries.$key2 -eq "1") {
                Return
            }
        }

        # Remove version info from path
        $revNameAlt = $revName
        if($entryPath.indexOf($revName) -gt 0 -and $entryPath.indexOf($verName) -lt 0) {
            $revIdx = $entryPath.indexOf($revName)
            $idx = $entryPath.indexOf($major)
            $revNameAlt = $entryPath.Substring($idx, $revIdx - $idx + $revName.Length)
        }
        $origEntryPath = $entryPath
        $entryPath = $entryPath.Replace("Sitecore ${verName}/", "Sitecore Website/").Replace("Sitecore ${revNameAlt}/", "Sitecore Website/")
        $entryPath = $entryPath.Replace("${revNameAlt}/", "/").Replace(" ${verName}/", "/")

        # Place all assemblies in shared assemblies folder
        $isAssembly = $name -like "*.dll" -or $name -like "*.dll.config" -or `
                      $name -like "*.exe" -or $name -like "*.exe.config"
        if($isAssembly) {
            $entryPath = "Assemblies\${name}"
        }
        
        # Now extract (or create folder)
        $targetPath = Join-Path $targetDir $entryPath
        if($entryPath -like "*/") {
            if(-not(Test-Path $targetPath)) {
                New-Item $targetPath -ItemType Directory | Out-Null
            }
        } else {
            $dir = Split-Path $targetPath -Parent
            if(-not(Test-Path $dir)) {
                New-Item $dir -ItemType Directory | Out-Null
            }

            $parent = Split-Path $targetPath -Parent
            if(-not (Test-Path $parent)) {
                New-Item $parent -ItemType Directory | Out-Null
            }

            If(-not (Test-Path $targetPath)) {
                Try {
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath)
                } Catch {
                    Write-Output ("Extract {0} ({1}) to {2}" -f $entry.FullName, $entryPath, $targetPath)
                    Write-Error $_
                    Exit
                }
            }
        }

        if($name -like "*.zip") {
            Write-Output "Extracting $targetPath..."
            [IO.Compression.ZipFile]::ExtractToDirectory($targetPath, "${targetPath} extracted")
        }
    }

    $zip.Dispose()

    # Decompile
    $assemblies = Get-ChildItem "$targetDir\Assemblies" -Filter "Sitecore.*.dll"
    $assemblyTarget = Join-Path $targetDir "Sitecore Decompiled"
    $assemblies | ForEach-Object {
        $name = $_.BaseName
        $fullname = $_.FullName
        Write-Output "Decompiling '$name' ($fullname)..."
        & $decompiler /lang:csharp /out:${assemblyTarget}\${name} /target:$fullname
    }

    # Commit
    if($Commit) {
        & git add -A
        & git commit -m "Added version $version"
        & git tag -a $tag
    }
}