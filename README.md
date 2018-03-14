# Sitecore Source

This project will contain decompiled Sitecore source code for different versions.

The purpose is solely to [see differences](https://help.github.com/articles/comparing-commits-across-time/) between different versions of Sitecore to achieve better knowledge of what have been changed/fixed/added - and asses the impact of a specific upgrade.

## Structure

There is a branch for each major version. Each version is extracted and added as a commit and tagged with that specific version.

Sitecore files and decompiled sources are located in the [Sitecore folder](./Sitecore)

## How versions are added

We have two options:

1. From official Sitecore NuGet feed. This only contains assemblies (not other files from website root). To use this you run:

```powershell
./bld/Get-VersionsFromNuGet.ps1 -Download -OnlyNew
./bld/Process-Packages.ps1 [-Commit] [-MajorVersions 8,9] [-Versions 9.0.171002]
```

1. Download the "ZIP archive of the Sitecore site root folder" and place it in the [downloads folder(./downloads). Then run:

```powershell
./bld/Get-VersionsFromSitecoreDev.ps1 -Username <your-sdn-username> -Password <you-sdn-password> -Download -OnlyNew
./bld/Process-Downloads.ps1 [-Commit] [-MajorVersions 8,9] [-Versions 9.0.171002]
```

## Prerequisities

* [Install justDecompile](https://www.telerik.com/download-trial-file/v2/justdecompile)
* NuGet must be in your path for ``Get-VersionsFromNuGet``.
