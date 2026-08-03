[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$PackagePath,

    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$ReleaseNotesPath,

    [Parameter(Mandatory = $true)]
    [string]$Token
)

$ErrorActionPreference = "Stop"
$repository = "CometTheFrog/AethernetExplorer-Repo"
$tag = "v$Version"

if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "AETHERNET_REPO_TOKEN is empty."
}
foreach ($path in @($PackagePath, $ManifestPath, $ReleaseNotesPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required release file is missing: $path"
    }
}

$env:GH_TOKEN = $Token

# Refuse to overwrite an existing published version.
& gh release view $tag --repo $repository *> $null
if ($LASTEXITCODE -eq 0) {
    throw "Release $tag already exists in $repository. Increase the version."
}

& gh release create $tag $PackagePath `
    --repo $repository `
    --target main `
    --title "Aethernet Explorer $Version Alpha" `
    --notes-file $ReleaseNotesPath `
    --prerelease

if ($LASTEXITCODE -ne 0) {
    throw "GitHub release creation failed."
}

# Update pluginmaster.json on the distribution repository's main branch.
$current = & gh api `
    -H "Accept: application/vnd.github+json" `
    "repos/$repository/contents/pluginmaster.json?ref=main" |
    ConvertFrom-Json

if ($LASTEXITCODE -ne 0 -or $null -eq $current.sha) {
    throw "Could not read pluginmaster.json from $repository."
}

$bytes = [System.IO.File]::ReadAllBytes(
    (Resolve-Path -LiteralPath $ManifestPath))
$content = [Convert]::ToBase64String($bytes)

$body = [ordered]@{
    message = "Publish Aethernet Explorer $Version"
    content = $content
    sha = $current.sha
    branch = "main"
} | ConvertTo-Json -Depth 10

$tempBody = Join-Path $env:RUNNER_TEMP "aethernet-pluginmaster-update.json"
Set-Content -LiteralPath $tempBody -Value $body -Encoding UTF8

& gh api `
    --method PUT `
    -H "Accept: application/vnd.github+json" `
    "repos/$repository/contents/pluginmaster.json" `
    --input $tempBody

if ($LASTEXITCODE -ne 0) {
    throw "pluginmaster.json update failed."
}

Write-Host "Published $tag and updated the Dalamud feed." -ForegroundColor Green
