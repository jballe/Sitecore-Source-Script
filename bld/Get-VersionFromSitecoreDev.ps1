param(
    [Parameter(Mandatory=$True)]
    [string]$Username, 
    [Parameter(Mandatory=$True)]
    $Password,
    [Switch]
    $OnlyNew,
    [Switch]
    $Download
)


$credentials = @{
    username = $Username
    password = $Password 
}

$rootUrl = "https://dev.sitecore.net/"
$loginurl = "${rootUrl}api/authorization" 
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

write-Host "Login with user $username..."
$login = Invoke-RestMethod -Method Post -Uri $loginurl -Body (ConvertTo-Json $credentials) -ContentType "application/json;charset=UTF-8" -WebSession $session
If($login -ne $True) {
    Write-Warning "Incorrect username or password"
    Exit
}

$targetFolder = Join-Path $PSScriptRoot "../downloads" -Resolve
Write-Host "Downloading overview page..."
$downloadOverview = Invoke-WebRequest -Uri "${rootUrl}Downloads/Sitecore_Experience_Platform.aspx" -WebSession $session
$downloadPages = $downloadOverview.ParsedHtml.links | Where-Object { $_.href -like "*/en/Downloads/*" } | ForEach-Object { $_.href.Replace("about:", $rootUrl) }
Write-Host ("Found {0} version pages to download" -f $downloadPages.Length)
$versions = @()
$downloadPages | ForEach-Object {
    Write-Host ("Downloading version page ({0})..." -f (Split-Path $_ -Leaf))
    $page = Invoke-WebRequest -Uri $_ -WebSession $session
    $needle = "<strong>Sitecore Experience Platform"
    $idx1 = $page.Content.IndexOf($needle)
    $idx2 = $page.Content.IndexOf("(", $idx1)
    $start = $idx1 + $needle.Length + 1
    $length = $idx2 - $start - 1
    $ver = $page.Content.Substring($start, $length)
    $filename = "Sitecore ${ver}.zip"
    $url = $page.ParsedHtml.links | Where-Object {$_.InnerText -like "ZIP archive *" } | Select-Object -First 1 -ExpandProperty href
    $url = $url.Replace("about:", $rootUrl)
    $targetPath = Join-Path $targetFolder $_.Filename
    $versions += @{Version = $ver; Url=$url; Filename=$filename; Target=$targetPath}
}

if($OnlyNew) {
    $versions = $versions | Where-Object {
        $include = Test-Path $_.Target
        Return $include
    }
}

$versions | Format-Table -Property Version, Filename, Url

if($Download) {
    $versions | ForEach-Object {
        Write-Host "Downloading ${_.Filename}..."
        Invoke-WebRequest -Uri $_.Url -WebSession $session -OutFile $_.Target -UseBasicParsing -TimeoutSec (60 * 10)

    }
}
