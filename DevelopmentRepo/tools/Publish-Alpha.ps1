[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')]
    [string]$Version
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$status = git status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw "This folder is not a Git repository."
}
if (-not [string]::IsNullOrWhiteSpace(($status -join "`n"))) {
    throw "Commit or stash your current changes before publishing."
}

$projectPath = Join-Path $root "AethernetExplorer.Plugin\AethernetExplorer.Plugin.csproj"
$manifestPath = Join-Path $root "AethernetExplorer.Plugin\AethernetExplorer.Plugin.json"

[xml]$project = Get-Content -LiteralPath $projectPath -Raw
$propertyGroup = $project.Project.PropertyGroup |
    Where-Object { $_.AssemblyVersion } |
    Select-Object -First 1
$propertyGroup.AssemblyVersion = $Version
$project.Save($projectPath)

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.AssemblyVersion = $Version
$manifest |
    ConvertTo-Json -Depth 20 |
    Set-Content -LiteralPath $manifestPath -Encoding UTF8

git add -- $projectPath $manifestPath
git commit -m "Release Aethernet Explorer $Version"
if ($LASTEXITCODE -ne 0) {
    throw "Version commit failed."
}

$tag = "v$Version"
git tag -a $tag -m "Aethernet Explorer $Version Alpha"
if ($LASTEXITCODE -ne 0) {
    throw "Tag creation failed."
}

git push origin HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Commit push failed."
}

git push origin $tag
if ($LASTEXITCODE -ne 0) {
    throw "Tag push failed."
}

Write-Host "Published $tag. GitHub Actions will build and distribute it." -ForegroundColor Green
