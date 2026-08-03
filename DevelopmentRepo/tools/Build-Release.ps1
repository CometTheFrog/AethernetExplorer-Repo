[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $root "AethernetExplorer.Plugin\AethernetExplorer.Plugin.csproj"
$sourceManifestPath = Join-Path $root "AethernetExplorer.Plugin\AethernetExplorer.Plugin.json"
$buildScript = Join-Path $root "Build-TestPackage.ps1"
$packageRoot = Join-Path $root "TestPackage\AethernetExplorer"

if (-not (Test-Path -LiteralPath $projectPath)) {
    throw "Plugin project was not found: $projectPath"
}
if (-not (Test-Path -LiteralPath $sourceManifestPath)) {
    throw "Plugin manifest was not found: $sourceManifestPath"
}
if (-not (Test-Path -LiteralPath $buildScript)) {
    throw "Build-TestPackage.ps1 was not found: $buildScript"
}

New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null

# Keep the assembly and manifest versions aligned for this build.
[xml]$project = Get-Content -LiteralPath $projectPath -Raw
$propertyGroup = $project.Project.PropertyGroup |
    Where-Object { $_.AssemblyVersion } |
    Select-Object -First 1

if ($null -eq $propertyGroup) {
    throw "The plugin project does not contain AssemblyVersion."
}

$propertyGroup.AssemblyVersion = $Version

if ($null -eq $propertyGroup.Version) {
    $versionNode = $project.CreateElement("Version")
    $versionNode.InnerText = $Version
    [void]$propertyGroup.AppendChild($versionNode)
}
else {
    $propertyGroup.Version = $Version
}

if ($null -eq $propertyGroup.FileVersion) {
    $fileVersionNode = $project.CreateElement("FileVersion")
    $fileVersionNode.InnerText = $Version
    [void]$propertyGroup.AppendChild($fileVersionNode)
}
else {
    $propertyGroup.FileVersion = $Version
}

$project.Save($projectPath)

$manifest = Get-Content -LiteralPath $sourceManifestPath -Raw |
    ConvertFrom-Json

$manifest.AssemblyVersion = $Version

# The Dalamud SDK project is the source of truth for InternalName.
$internalName = [string]$propertyGroup.InternalName
if (-not [string]::IsNullOrWhiteSpace($internalName)) {
    $manifest.InternalName = $internalName
}

$manifest |
    ConvertTo-Json -Depth 20 |
    Set-Content -LiteralPath $sourceManifestPath -Encoding UTF8

& $buildScript -Configuration Release
if ($LASTEXITCODE -ne 0) {
    throw "Build-TestPackage.ps1 failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $packageRoot)) {
    throw "Package output was not created: $packageRoot"
}

# Ensure the ZIP contains an accurate manifest. Prefer the SDK-generated one;
# fall back to the source manifest if the SDK output does not include it.
$packageManifest = Join-Path $packageRoot "AethernetExplorer.Plugin.json"
if (Test-Path -LiteralPath $packageManifest) {
    $packaged = Get-Content -LiteralPath $packageManifest -Raw |
        ConvertFrom-Json
    $packaged.AssemblyVersion = $Version
    if (-not [string]::IsNullOrWhiteSpace($internalName)) {
        $packaged.InternalName = $internalName
    }
    $packaged |
        ConvertTo-Json -Depth 20 |
        Set-Content -LiteralPath $packageManifest -Encoding UTF8
}
else {
    Copy-Item -LiteralPath $sourceManifestPath -Destination $packageManifest -Force
}

$zipPath = Join-Path $OutputDirectory "AethernetExplorer.zip"
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

# Dalamud expects the plugin files at the root of the downloaded ZIP.
Compress-Archive `
    -Path (Join-Path $packageRoot "*") `
    -DestinationPath $zipPath `
    -CompressionLevel Optimal

$downloadUrl =
    "https://github.com/CometTheFrog/AethernetExplorer-Repo/releases/download/v$Version/AethernetExplorer.zip"

$unixTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()

$entry = [ordered]@{
    Author = $manifest.Author
    Name = $manifest.Name
    InternalName = $manifest.InternalName
    AssemblyVersion = $Version
    TestingAssemblyVersion = $null
    Description = $manifest.Description
    ApplicableVersion = $manifest.ApplicableVersion
    RepoUrl = "https://github.com/CometTheFrog/AethernetExplorer"
    DalamudApiLevel = [int]$manifest.DalamudApiLevel
    Punchline = $manifest.Punchline
    AcceptsFeedback = [bool]$manifest.AcceptsFeedback
    IsHide = $false
    IsTestingExclusive = $false
    DownloadLinkInstall = $downloadUrl
    DownloadLinkUpdate = $downloadUrl
    DownloadLinkTesting = $null
    LastUpdate = $unixTime
    Tags = @($manifest.Tags)
    CategoryTags = @($manifest.CategoryTags)
}

@($entry) |
    ConvertTo-Json -Depth 20 |
    Set-Content `
        -LiteralPath (Join-Path $OutputDirectory "pluginmaster.json") `
        -Encoding UTF8

Write-Host "Release package: $zipPath" -ForegroundColor Green
Write-Host "Repository feed: $(Join-Path $OutputDirectory 'pluginmaster.json')" -ForegroundColor Green
